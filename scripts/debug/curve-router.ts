import * as config from "../constants";
import { ethers } from "hardhat";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";

async function main() {
  const CurveRouter = await ethers.getContractFactory("CurveRouter");
  const instance = await CurveRouter.deploy();

  // impersonate ARTH whale
  const address = "0xeccE08c2636820a81FC0c805dBDC7D846636bbc4";
  await helpers.impersonateAccount(address);
  await helpers.setBalance(address, "0x56BC75E2D63100000");

  const lpTokenAddr = "0xdf34bad1d3b16c8f28c9cf95f15001949243a038";
  const poolAddr = "0xb4018cb02e264c3fcfe0f21a1f5cfbcaaba9f61f";

  console.log("init");
  await instance.initialize(
    config.gnosisSafe, // address _treasury,
    poolAddr, // ICurveCryptoV2 _pool,
    lpTokenAddr, // IERC20 _poolToken,
    config.arthAddr, // IERC20 _arth,
    config.usdcAddr // IERC20 _usdc
  );

  const lpToken = await ethers.getContractAt("IERC20", lpTokenAddr);
  const arth = await ethers.getContractAt("IERC20", config.arthAddr);
  const whale = await ethers.getSigner(address);

  const balance = await arth.balanceOf(whale.address);
  console.log("balance of whale", balance);

  console.log("giving approval to contract");
  await arth.connect(whale).approve(instance.address, balance);

  // perform checkUpkeep
  const abiEncoder = new ethers.utils.AbiCoder();
  const checkData = abiEncoder.encode(["uint256"], [balance]);
  console.log("check data", checkData);
  const ret = await instance.checkUpkeep(checkData);
  console.log("peformData", ret.performData);

  console.log("lp tokens in treasury");
  console.log((await lpToken.balanceOf(config.gnosisSafe)).toString());

  // perform performUpkeep
  console.log("executing lp strategy");
  await instance.connect(whale).performUpkeep(ret.performData);

  console.log("lp tokens in treasury");
  console.log((await lpToken.balanceOf(config.gnosisSafe)).toString());

  await instance.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
