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
    IRouter[3] routers;
    IERC20 ARTH = IERC20(0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71);
    IERC20 MAHA = IERC20(0x745407c86DF8DB893011912d3aB28e68B62E49B0);
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    enum PoolIndex { ARTH_USDC, ARTH_MAHA, ARTH_WETH }

    struct RouterConfig {
        bool paused;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 tokenAmin;
        uint256 tokenBmin;
        PoolIndex index;
    }

    mapping(address => RouterConfig) public configs;
    address private me;

    event RouterConfigSet(
        address indexed who,
        address router,
        RouterConfig config
    );

    event RouterToggled(address indexed who, address router, bool val); 

    function initialize(address _treasury) external initializer {
        _transferOwnership(_treasury);
        me = address(this);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    /// @dev router[0] = curveRouter, router[1] = ARTH-MAHA, router[2] = ARTH-WETH
    /// @param router the address of router
    /// @param config config data related to router tokenA and tokenB address and tokenMin values and poolIndex
    function setRouterConfig(
        address router,
        RouterConfig memory config
    ) external onlyOwner {
        routers[uint256(config.index)] = IRouter(router);
        configs[router] = config;
        emit RouterConfigSet(msg.sender, router, config);
    }

    function toggleRouter(address router) external onlyOwner {
        configs[router].paused = !configs[router].paused;
        emit RouterToggled(msg.sender, router, configs[router].paused);
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
            address router = address(routers[i]);
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
        IRouter[] memory validRouters = abi.decode(performData, (IRouter[]));

        // for (uint i = 0; i < validRouters.length; i++)
        //     validRouters[i].execute();

        emit PerformUpkeep(msg.sender, performData);
    }

    function addLiquidityToPool() external {
        uint256 arthBalance;
        uint256 mahaBalance = MAHA.balanceOf(address(this));
        address(WETH).call{value: address(this).balance}(abi.encodePacked("depoist()"));
        uint256 wethBalance = WETH.balanceOf(address(this));

        arthBalance = ARTH.balanceOf(address(this));
        ARTH.approve(address(routers[uint256(PoolIndex.ARTH_USDC)]), arthBalance);
        routers[uint256(PoolIndex.ARTH_USDC)].execute(arthBalance / 2, 0, abi.encode(uint256(0)));     // 50% balance of arth
        arthBalance = ARTH.balanceOf(address(this));
        ARTH.approve(address(routers[uint256(PoolIndex.ARTH_MAHA)]), arthBalance / 2);
        MAHA.approve(address(routers[uint256(PoolIndex.ARTH_MAHA)]), mahaBalance);
        // 25% balance of arth
        routers[uint256(PoolIndex.ARTH_MAHA)].execute(
            arthBalance / 2,
            mahaBalance, 
            abi.encode(
                configs[address(routers[uint256(PoolIndex.ARTH_MAHA)])].tokenAmin,
                configs[address(routers[uint256(PoolIndex.ARTH_MAHA)])].tokenBmin
            )
        );
        // 25% balance of arth (the rest amount)
        arthBalance = ARTH.balanceOf(address(this));
        ARTH.approve(address(routers[uint256(PoolIndex.ARTH_WETH)]), arthBalance);
        MAHA.approve(address(routers[uint256(PoolIndex.ARTH_WETH)]), wethBalance);
        routers[uint256(PoolIndex.ARTH_WETH)].execute(
            arthBalance, 
            wethBalance, 
            abi.encode(
                configs[address(routers[uint256(PoolIndex.ARTH_WETH)])].tokenAmin,
                configs[address(routers[uint256(PoolIndex.ARTH_WETH)])].tokenBmin
            )
        );
    }
}
