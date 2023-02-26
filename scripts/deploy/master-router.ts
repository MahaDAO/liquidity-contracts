import * as config from "../constants";
import { ethers } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";

async function main() {
  console.log("deploy router for maha/weth pool");

  const [deployer] = await ethers.getSigners();
  console.log("i am", deployer.address);

  const implementation = await deployOrLoadAndVerify(
    `MasterRouter-Impl`,
    "MasterRouter",
    []
  );

  const MasterRouter = await ethers.getContractFactory("MasterRouter");
  const initData = MasterRouter.interface.encodeFunctionData("initialize", [
    config.gnosisSafe, // address _treasury,
    config.arthAddr, // IERC20 _arth,
    config.mahaAddr, // IERC20 _maha,
    config.wethAddr, // IWETH _weth
    "0xB1E961aC401A2cE5a267616C6843a3424c60b01c", // IRouter _curveRouter,
    "0x32ffe78b774990279456466f0eb6a08cf096bca5", // IRouter _mahaWethRouter
  ]);

  await deployOrLoadAndVerify(`MasterRouter`, "TransparentUpgradeableProxy", [
    implementation.address,
    config.gnosisSafe,
    initData,
  ]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
