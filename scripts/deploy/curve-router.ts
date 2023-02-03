import * as config from "../constants";
import { ethers } from "hardhat";

async function main() {
  const CurveRouter = await ethers.getContractFactory("CurveRouter");
  const instance = await CurveRouter.deploy();

  await instance.initialize(
    config.gnosisSafe, // address _treasury,
    "0xb4018cb02e264c3fcfe0f21a1f5cfbcaaba9f61f", // ICurveCryptoV2 _pool,
    "0xdf34bad1d3b16c8f28c9cf95f15001949243a038", // IERC20 _poolToken,
    config.arthAddr, // IERC20 _arth,
    config.usdcAddr // IERC20 _usdc
  );

  await instance.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
