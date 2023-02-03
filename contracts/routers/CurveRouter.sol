// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IRouter} from "../interfaces/IRouter.sol";
import {VersionedInitializable} from "../proxy/VersionedInitializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveCryptoV2} from "../interfaces/ICurveCryptoV2.sol";

contract CurveRouter is Ownable, VersionedInitializable, IRouter {
    address me;

    ICurveCryptoV2 public pool;
    IERC20 public poolToken;
    IERC20 public arth;
    IERC20 public usdc;

    function initialize(
        address _treasury,
        ICurveCryptoV2 _pool,
        IERC20 _poolToken,
        IERC20 _arth,
        IERC20 _usdc
    ) external initializer {
        me = address(this);

        pool = _pool;
        poolToken = _poolToken;
        arth = _arth;
        usdc = _usdc;

        _transferOwnership(_treasury);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function execute(
        uint256 tokenArthAmount,
        uint256,
        bytes calldata extraData
    ) external override {
        uint256 minLptokens = abi.decode(extraData, (uint256));

        // take tokens from the master router
        arth.transferFrom(msg.sender, me, tokenArthAmount);

        // add to liquidity on curve (single side)
        pool.add_liquidity([tokenArthAmount, 0], minLptokens, true);

        // send the lp tokens to the treasury
        poolToken.transfer(owner(), poolToken.balanceOf(me));
    }

    function tokens() external view override returns (address, address) {
        return (address(arth), address(usdc));
    }
}
