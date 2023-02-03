// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {VersionedInitializable} from "../proxy/VersionedInitializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveCryptoV2} from "../interfaces/ICurveCryptoV2.sol";

// collect tokens and use it to add liquidity to ARTH/ETH and ARTH/MAHA LP pairs.
contract UniswapV3Router is Ownable, VersionedInitializable, IRouter {
    address me;

    INonfungiblePositionManager public manager;
    uint256 public poolId;
    IERC20 public token0;
    IERC20 public token1;

    function initialize(
        address _treasury,
        INonfungiblePositionManager _manager,
        uint256 _poolId,
        IERC20 _token0,
        IERC20 _token1
    ) external initializer {
        me = address(this);

        manager = _manager;
        poolId = _poolId;
        token0 = _token0;
        token1 = _token1;

        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);

        _transferOwnership(_treasury);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function _execute(
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal {
        // take tokens from the master router
        token0.transferFrom(msg.sender, me, token0Amount);
        token1.transferFrom(msg.sender, me, token1Amount);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: poolId,
                    amount0Desired: token0Amount,
                    amount1Desired: token1Amount,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                });

        manager.increaseLiquidity(params);
    }

    function execute(
        uint256 token0Amount,
        uint256 token1Amount,
        bytes calldata extraData
    ) external override {
        (uint256 amount0Min, uint256 amount1Min) = abi.decode(
            extraData,
            (uint256, uint256)
        );

        _execute(token0Amount, token1Amount, amount0Min, amount1Min);
    }

    function checkUpkeep(
        bytes calldata checkData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (checkData.length > 0) {
            (uint256 token0Amount, uint256 token1Amount) = abi.decode(
                checkData,
                (uint256, uint256)
            );

            // uint256 minLptokens = pool.calc_token_amount([tokenArthAmount, 0]);
            return (true, abi.encode(token0Amount, token1Amount, 0, 0));
        }

        return (
            false,
            abi.encode(uint256(0), uint256(0), uint256(0), uint256(0))
        );
    }

    function performUpkeep(bytes calldata performData) external {
        (
            uint256 token0Amount,
            uint256 token1Amount,
            uint256 amount0Min,
            uint256 amount1Min
        ) = abi.decode(performData, (uint256, uint256, uint256, uint256));
        _execute(token0Amount, token1Amount, amount0Min, amount1Min);
        emit PerformUpkeep(msg.sender, performData);
    }

    function tokens() external view override returns (address, address) {
        return (address(token0), address(token1));
    }

    function refundPosition(uint256 nftId) external onlyOwner {
        manager.transferFrom(me, owner(), nftId);
    }

    function setPoolId(uint256 nftId) external onlyOwner {
        poolId = nftId;
    }
}
