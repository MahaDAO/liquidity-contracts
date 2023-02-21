// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import {IRouter} from "./interfaces/IRouter.sol";
import {VersionedInitializable} from "./proxy/VersionedInitializable.sol";
import {KeeperCompatibleInterface} from "./interfaces/KeeperCompatibleInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CurveRouter} from "./routers/CurveRouter.sol";

contract MasterRouter is
    Ownable,
    VersionedInitializable,
    KeeperCompatibleInterface
{
    IRouter[] routers;
    IERC20 ARTH = IERC20(0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71);
    IERC20 MAHA = IERC20(0x745407c86DF8DB893011912d3aB28e68B62E49B0);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    struct RouterConfig {
        bool paused;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 tokenAmin;
        uint256 tokenBmin;
    }

    mapping(IRouter => RouterConfig) public configs;
    address private me;

    event RouterConfigSet(
        address indexed who,
        IRouter router,
        RouterConfig config
    );

    event RouterToggled(address indexed who, IRouter router, bool val); 

    function initialize(address _treasury) external initializer {
        _transferOwnership(_treasury);
        me = address(this);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function setRouterConfig(
        IRouter router,
        RouterConfig memory config
    ) external onlyOwner {
        routers.push(router);
        configs[router] = config;
        emit RouterConfigSet(msg.sender, router, config);
    }

    function toggleRouter(IRouter router) external onlyOwner {
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
            IRouter router = routers[i];
            RouterConfig memory config = configs[router];

            // sanity checks
            if (address(config.tokenA) == address(0)) continue;
            if (config.paused) continue;
            if (j == length) break;

            // TODO; calculate how much would be spent
            // if

            // if all good, then add to results.
            validRouters[j++] = router;
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
        uint256 arthBalance = ARTH.balanceOf(address(this));
        uint256 mahaBalance = MAHA.balanceOf(address(this));
        uint256 wethBalance = WETH.balanceOf(address(this));

        
    }
}
