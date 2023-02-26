// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import {IRouter} from "./interfaces/IRouter.sol";
import {VersionedInitializable} from "./proxy/VersionedInitializable.sol";
import {KeeperCompatibleInterface} from "./interfaces/KeeperCompatibleInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";

contract MasterRouter is
    Ownable,
    VersionedInitializable,
    KeeperCompatibleInterface
{
    IERC20 public arth;
    IERC20 public maha;
    IWETH public weth;

    address private me;

    IRouter public curveRouter;
    IRouter public mahaWethRouter;
    IRouter public arthMahaRouter;

    receive() external payable {
        weth.deposit{value: msg.value}();
    }

    function initialize(
        address _treasury,
        IRouter _curveRouter,
        IRouter _arthMahaRouter,
        IRouter _mahaWethRouter,
        IERC20 _arth,
        IERC20 _maha,
        IWETH _weth
    ) external initializer {
        _transferOwnership(_treasury);
        me = address(this);

        curveRouter = _curveRouter;
        arthMahaRouter = _arthMahaRouter;
        mahaWethRouter = _mahaWethRouter;
        arth = _arth;
        maha = _maha;
        weth = _weth;

        // give approvals to routers
        arth.approve(address(curveRouter), type(uint256).max);
        maha.approve(address(arthMahaRouter), type(uint256).max);
        weth.approve(address(mahaWethRouter), type(uint256).max);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function checkUpkeep(
        bytes calldata
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // how much routers at a time should we consider?
        uint256 length = abi.decode(performData, (uint256));

        // prepare the return data
        IRouter[] memory validRouters = new IRouter[](length);
        // uint256 j = 0;

        // TODO; need to write some checks and balances

        // for (uint i = 0; i < routers.length; i++) {
        //     IRouter router = routers[i];
        //     RouterConfig memory config = configs[router];

        //     // sanity checks
        //     if (address(config.tokenA) == address(0)) continue;
        //     if (config.paused) continue;
        //     if (j == length) break;

        //     // TODO; calculate how much would be spent
        //     // if

        //     // if all good, then add to results.
        //     validRouters[j++] = IRouter(router);
        // }

        return (false, abi.encode(validRouters));
    }

    function performUpkeep(bytes calldata performData) external {
        (
            bool _executeArthMaha,
            bytes memory _arthMahaData,
            bool _executeMahaWeth,
            bytes memory _mahaWethData,
            bool _executeCurve,
            bytes memory _curveData
        ) = abi.decode(performData, (bool, bytes, bool, bytes, bool, bytes));

        if (_executeArthMaha) arthMahaRouter.performUpkeep(_arthMahaData);
        if (_executeMahaWeth) mahaWethRouter.performUpkeep(_mahaWethData);
        if (_executeCurve) curveRouter.performUpkeep(_curveData);
    }

    /// @dev helper function to get add liquidty to all the pools in one go.
    function addLiquidityToPool() external {
        executeCurve();
        executeUniswapARTHMAHA();
        executeUniswapMAHAWETH();
    }

    /// @notice adds whatever ARTH is in this contract into the curve pool
    function executeCurve() public {
        uint256 arthBalance = arth.balanceOf(me);

        // token0 is ARTH and token1 is USDC according to the curve pool
        if (arthBalance > 0)
            curveRouter.execute(
                arthBalance,
                0,
                abi.encode(uint256(0), uint256(0))
            );
    }

    /// @notice adds whatever MAHA is in this contract into the ARTH/MAHA 1% Uniswap pool
    function executeUniswapARTHMAHA() public {
        uint256 mahaBalance = maha.balanceOf(me);

        // token0 is MAHA Token and token1 is ARTH Token according to the Uniswap v3 pool
        if (mahaBalance > 0)
            arthMahaRouter.execute(
                mahaBalance,
                0,
                abi.encode(uint256(0), uint256(0))
            );
    }

    /// @notice adds whatever WETH is in this contract into the WETH/MAHA 1% Uniswap pool
    function executeUniswapMAHAWETH() public {
        uint256 wethBalance = weth.balanceOf(me);

        // token0 is MAHA Token and token1 is WETH Token according to the Uniswap v3 pool
        if (wethBalance > 0)
            mahaWethRouter.execute(
                0,
                wethBalance,
                abi.encode(uint256(0), uint256(0))
            );
    }
}
