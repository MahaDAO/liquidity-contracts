// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import {IRouter} from "./interfaces/IRouter.sol";
import {VersionedInitializable} from "./proxy/VersionedInitializable.sol";
import {KeeperCompatibleInterface} from "./interfaces/KeeperCompatibleInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MasterRouter is
    Ownable,
    VersionedInitializable,
    KeeperCompatibleInterface
{
    IRouter public curveRouter;
    IRouter public arthMahaRouter;
    IRouter public arthWethRouter;

    IERC20 public arth;
    IERC20 public maha;
    IERC20 public weth;

    address private me;

    function initialize(
        address _treasury,
        IRouter _curveRouter,
        IRouter _arthMahaRouter,
        IRouter _arthWethRouter,
        IERC20 _arth,
        IERC20 _maha,
        IERC20 _weth
    ) external initializer {
        _transferOwnership(_treasury);
        me = address(this);

        curveRouter = _curveRouter;
        arthMahaRouter = _arthMahaRouter;
        arthWethRouter = _arthWethRouter;
        arth = _arth;
        maha = _maha;
        weth = _weth;

        // give approvals to routers
        arth.approve(address(curveRouter), type(uint256).max);
        arth.approve(address(arthMahaRouter), type(uint256).max);
        arth.approve(address(arthWethRouter), type(uint256).max);
        maha.approve(address(arthMahaRouter), type(uint256).max);
        weth.approve(address(arthWethRouter), type(uint256).max);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool, bytes memory) {
        uint256 curveRouterArthAmount = arth.balanceOf(me);
        bytes memory data3 = abi.encode(curveRouterArthAmount);
        bytes memory _curveData;
        // bool a;

        bool executeArthMaha;
        bytes memory arthMahaData;
        bool executeArthWeth;
        bytes memory arthWethData;
        bool executeCurve;
        bytes memory curveData;

        (executeCurve, _curveData) = curveRouter.checkUpkeep(data3);

        return (
            false,
            abi.encode(
                executeArthMaha,
                arthMahaData,
                executeArthWeth,
                arthWethData,
                executeCurve,
                curveData
            )
        );
    }

    function performUpkeep(bytes calldata performData) external {
        (
            bool executeArthMaha,
            bytes memory arthMahaData,
            bool executeArthWeth,
            bytes memory arthWethData,
            bool executeCurve,
            bytes memory curveData
        ) = abi.decode(performData, (bool, bytes, bool, bytes, bool, bytes));

        // first send ARTH & MAHA to the ARTH/MAHA Router (based on MAHA collected)
        if (executeArthMaha) arthMahaRouter.performUpkeep(arthMahaData);

        // second send ARTH & WETH to the ARTH/WETH Router (based on WETH collected)
        if (executeArthWeth) arthWethRouter.performUpkeep(arthWethData);

        // third send remaining ARTH to the Curve Router (based on ARTH left over)
        if (executeCurve) arthMahaRouter.performUpkeep(curveData);
    }
}
