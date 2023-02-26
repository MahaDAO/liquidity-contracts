import * as config from "../constants";
import { ethers } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";

async function main() {
  console.log("deploy router for maha/weth pool");

  const poolAddress = "0xb28ddf1ee8ee014eafbecd8de979ac8d297931c7";
  const nftId = 447449;

  const [deployer] = await ethers.getSigners();
  console.log("i am", deployer.address);

  const implementation = await deployOrLoadAndVerify(
    `UniswapV3Router-Impl`,
    "UniswapV3Router",
    []
  );

  const UniswapV3Router = await ethers.getContractFactory("UniswapV3Router");
  const initData = UniswapV3Router.interface.encodeFunctionData("initialize", [
    config.gnosisSafe, // address _treasury,
    config.uniswapNFTPositionMangerAddr, // INonfungiblePositionManager _manager,
    poolAddress, // IUniswapV3Pool _pool,
    config.uniswapSwapRouter, // ISwapRouter _swapRouter,
    nftId, // uint256 _poolId
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
