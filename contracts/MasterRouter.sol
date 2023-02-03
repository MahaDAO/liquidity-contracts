// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import {IRouter} from "./interfaces/IRouter.sol";
import {VersionedInitializable} from "./proxy/VersionedInitializable.sol";
import {KeeperCompatibleInterface} from "./interfaces/KeeperCompatibleInterface.sol";
import {Epoch} from "./utils/Epoch.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MasterRouter is
    Epoch,
    VersionedInitializable,
    KeeperCompatibleInterface
{
    IRouter[] routers;

    struct RouterConfig {
        bool paused;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 tokenAmin;
        uint256 tokenBmin;
    }

    mapping(IRouter => RouterConfig) public configs;

    event RouterConfigSet(
        address indexed who,
        IRouter router,
        RouterConfig config
    );

    event UpkeepPerformed(
        address indexed who,
        IRouter router,
        RouterConfig config
    );

    function initializz(address _treasury) external initializer {
        // daily epoch
        _initializeEpoch(86400, block.timestamp, 0);
        _transferOwnership(_treasury);
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

            // if all good, then add to results.
            validRouters[j++] = router;
        }

        return (false, abi.encode(validRouters));
    }

    function performUpkeep(bytes calldata performData) external {
        IRouter[] memory validRouters = abi.decode(performData, (IRouter[]));

        for (uint i = 0; i < validRouters.length; i++)
            validRouters[i].execute();

        emit PerformUpkeep(msg.sender, performData);
    }
}
