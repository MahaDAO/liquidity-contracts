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
    IRouter public arthMahaRouter;
    IRouter public arthWethRouter;

    IRouter[3] routers;

    enum PoolIndex {
        ARTH_USDC,
        ARTH_MAHA,
        ARTH_WETH
    }

    struct RouterConfig {
        bool paused;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 tokenAmin;
        uint256 tokenBmin;
        PoolIndex index;
    }

    mapping(IRouter => RouterConfig) public configs;

    event RouterConfigSet(
        address indexed who,
        address router,
        RouterConfig config
    );

    event RouterToggled(address indexed who, address router, bool val);

    function initialize(
        address _treasury,
        IRouter _curveRouter,
        IRouter _arthMahaRouter,
        IRouter _arthWethRouter,
        IERC20 _arth,
        IERC20 _maha,
        IWETH _weth
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

    /// @dev router[0] = curveRouter, router[1] = ARTH-MAHA, router[2] = ARTH-WETH
    /// @param router the address of router
    /// @param config config data related to router tokenA and tokenB address and tokenMin values and poolIndex
    function setRouterConfig(
        IRouter router,
        RouterConfig memory config
    ) external onlyOwner {
        routers[uint256(config.index)] = IRouter(router);
        configs[router] = config;
        emit RouterConfigSet(msg.sender, address(router), config);
    }

    function toggleRouter(IRouter router) external onlyOwner {
        configs[router].paused = !configs[router].paused;
        emit RouterToggled(msg.sender, address(router), configs[router].paused);
    }

    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // how much routers at a time should we consider?
        uint256 length = abi.decode(performData, (uint256));

        // prepare the return data
        IRouter[] memory validRouters = new IRouter[](length);
        uint256 j = 0;

        for (uint i = 0; i < routers.length; i++) {
            IRouter router = routers[i];
            RouterConfig memory config = configs[router];

            // sanity checks
            if (address(config.tokenA) == address(0)) continue;
            if (config.paused) continue;
            if (j == length) break;

            // TODO; calculate how much would be spent
            // if

            // if all good, then add to results.
            validRouters[j++] = IRouter(router);
        }

        return (false, abi.encode(validRouters));
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

    function addLiquidityToPool() external {
        if (me.balance > 0) weth.deposit{value: me.balance}();

        uint256 mahaBalance = maha.balanceOf(me);
        uint256 wethBalance = weth.balanceOf(me);
        uint256 arthBalance = arth.balanceOf(me);

        // 50% balance of arth
        curveRouter.execute(
            arthBalance / 2,
            0,
            abi.encode(uint256(0), uint256(0))
        );

        // 25% balance of arth and rest of maha
        arthMahaRouter.execute(
            arthBalance / 4,
            mahaBalance,
            abi.encode(
                configs[arthMahaRouter].tokenAmin,
                configs[arthMahaRouter].tokenBmin
            )
        );

        // 25% balance of arth and rest of weth
        arthWethRouter.execute(
            arthBalance / 4,
            wethBalance,
            abi.encode(
                configs[arthWethRouter].tokenAmin,
                configs[arthWethRouter].tokenBmin
            )
        );
    }
}
