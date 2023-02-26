import * as config from "../constants";
import { ethers } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";

async function main() {
  const nftManagerAddr = "0xc36442b4a4522e871399cd717abdd847ab11fe88";
  const nftManager = await ethers.getContractAt(
    "INonfungiblePositionManager",
    nftManagerAddr
  );
  const nftId = 447449;

  console.log("deploy router for maha/weth pool");

  const implementation = await deployOrLoadAndVerify(
    `UniswapV3Router-Impl`,
    "UniswapV3Router",
    []
  );

  const UniswapV3Router = await ethers.getContractFactory("UniswapV3Router");
  const initData = UniswapV3Router.interface.encodeFunctionData("initialize", [
    config.gnosisSafe, // address _treasury,
    nftManager.address, // INonfungiblePositionManager _manager,
    nftId, // uint256 _poolId,
    config.mahaAddr, // IERC20 _token0,
    config.wethAddr, // IERC20 _token1,
    10000, // uint24 _fee
  ]);

  await deployOrLoadAndVerify(
    `UniswapV3Router-MAHAWETH-10000`,
    "TransparentUpgradeableProxy",
    [implementation.address, config.gnosisSafe, initData]
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
