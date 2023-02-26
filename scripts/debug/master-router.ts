import * as config from "../constants";
import { ethers } from "hardhat";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";

async function main() {
  const poolAddress = "0xb28ddf1ee8ee014eafbecd8de979ac8d297931c7";
  // impersonate MAHA whale
  const address = "0x77cd66d59ac48a0E7CE54fF16D9235a5fffF335E";
  await helpers.impersonateAccount(address);
  await helpers.setBalance(address, "0x56BC75E2D63100000"); // give it some ETH balance

  const whale = await ethers.getSigner(address);
  const e18 = BigNumber.from(10).pow(18);

  console.log("deploy master router");
  const MasterRouter = await ethers.getContractFactory("MasterRouter");
  const instance = await MasterRouter.deploy();

  console.log("init");
  await instance.initialize(
    config.gnosisSafe, // address _treasury,
    config.arthAddr, // IERC20 _arth,
    config.mahaAddr, // IERC20 _maha,
    config.wethAddr, // IWETH _weth
    "0xB1E961aC401A2cE5a267616C6843a3424c60b01c", // IRouter _curveRouter,
    "0x32ffe78b774990279456466f0eb6a08cf096bca5" // IRouter _mahaWethRouter
  );

  const weth = await ethers.getContractAt("IWETH", config.wethAddr);

  console.log("deposit 1 eth into the weth contract");
  await weth.connect(whale).deposit({ value: e18 });

  const balance = await weth.balanceOf(whale.address);
  console.log("weth balance of whale", balance);

  console.log("send 1 weth to master contract");
  await weth.connect(whale).transfer(instance.address, balance);

  // perform checkUpkeep
  console.log("checkUpkeep");
  const results = await instance.checkUpkeep("0x");
  console.log("results", results);

  // // console.log("exec data", checkData);
  console.log("weth tokens in LP before");
  console.log((await weth.balanceOf(poolAddress)).toString());

  // console.log("execData", execData);

  console.log("executing lp strategy");
  await instance.performUpkeep(results.performData);
  // // console.log("peformData", ret.performData);

  console.log("weth tokens in LP after");
  console.log((await weth.balanceOf(poolAddress)).toString());

  // console.log("weth tokens in whale after");
  // console.log((await weth.balanceOf(whale.address)).toString());

  // console.log("weth tokens in contract after");
  // console.log((await weth.balanceOf(instance.address)).toString());

  // perform performUpkeep
  // await instance.connect(whale).performUpkeep(ret.performData);

  // console.log("lp tokens in treasury");
  // console.log((await lpToken.balanceOf(config.gnosisSafe)).toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
