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

    mapping(IERC20 => IRouter) public routers;
    mapping(IERC20 => uint256) public routerMinimum;

    event RegisterRouter(
        address who,
        IERC20 _token,
        IRouter _router,
        uint256 minNeeded
    );

    receive() external payable {
        weth.deposit{value: msg.value}();
    }

    function initialize(
        address _treasury,
        IERC20 _arth,
        IERC20 _maha,
        IWETH _weth
    ) external initializer {
        _transferOwnership(_treasury);
        me = address(this);

        arth = _arth;
        maha = _maha;
        weth = _weth;
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function registerRouter(
        IERC20 _token,
        IRouter _router,
        uint256 minNeeded
    ) external onlyOwner {
        routerMinimum[_token] = minNeeded;
        routers[_token] = _router;

        _token.approve(address(_router), type(uint256).max);

        emit RegisterRouter(msg.sender, _token, _router, minNeeded);
    }

    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bool _executeMaha;
        bool _executeWeth;
        bool _executeArth;

        bytes memory dummyData = abi.encode(uint256(0), uint256(0));

        _executeArth = arth.balanceOf(me) > routerMinimum[arth];
        _executeWeth = weth.balanceOf(me) > routerMinimum[weth];
        _executeMaha = maha.balanceOf(me) > routerMinimum[maha];

        performData = abi.encode(
            _executeMaha,
            dummyData,
            _executeWeth,
            dummyData,
            _executeArth,
            dummyData
        );

        upkeepNeeded = _executeMaha || _executeWeth || _executeArth;
    }

    function performUpkeep(bytes calldata performData) external {
        (
            bool _executeMaha,
            bytes memory _mahaData,
            bool _executeWeth,
            bytes memory _wethData,
            bool _executeArth,
            bytes memory _arthData
        ) = abi.decode(performData, (bool, bytes, bool, bytes, bool, bytes));

        if (_executeMaha) routers[maha].performUpkeep(_mahaData);
        if (_executeWeth) routers[weth].performUpkeep(_wethData);
        if (_executeArth) routers[arth].performUpkeep(_arthData);
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
