import { ethers, network } from "hardhat";
import { deployOrLoadAndVerify, getOutputAddress } from "../utils";
import * as config from "../constants";

async function main() {
  console.log(`Deploying migrator to ${network.name}`);

  const [deployer] = await ethers.getSigners();
  console.log(`deployer address is ${deployer.address}`);

  const implementation = await deployOrLoadAndVerify(
    `CurveRouter-Impl`,
    "CurveRouter",
    []
  );

  const lpTokenAddr = "0xdf34bad1d3b16c8f28c9cf95f15001949243a038";
  const poolAddr = "0xb4018cb02e264c3fcfe0f21a1f5cfbcaaba9f61f";

  const CurveRouter = await ethers.getContractFactory("CurveRouter");
  const initData = CurveRouter.interface.encodeFunctionData("initialize", [
    config.gnosisSafe, // address _treasury,
    poolAddr, // ICurveCryptoV2 _pool,
    lpTokenAddr, // IERC20 _poolToken,
    config.arthAddr, // IERC20 _arth,
    config.usdcAddr, // IERC20 _usdc
  ]);

  await deployOrLoadAndVerify(`CurveRouter`, "TransparentUpgradeableProxy", [
    implementation.address,
    config.gnosisSafe,
    initData,
  ]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
