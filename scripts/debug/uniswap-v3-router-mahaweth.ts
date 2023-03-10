import * as config from "../constants";
import { ethers } from "hardhat";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";

async function main() {
  // impersonate MAHA whale
  const address = "0x77cd66d59ac48a0E7CE54fF16D9235a5fffF335E";
  await helpers.impersonateAccount(address);
  await helpers.setBalance(address, "0x56BC75E2D63100000"); // give it some ETH balance

  const whale = await ethers.getSigner(address);
  const e18 = BigNumber.from(10).pow(18);

  const poolAddress = "0xb28ddf1ee8ee014eafbecd8de979ac8d297931c7";
  const nftId = 447449;

  console.log("deploy router for maha/weth pool");
  // const UniswapV3Router = await ethers.getContractAt("UniswapV3Router", '0x32fFE78b774990279456466f0eb6A08cF096bca5');
  // const instance = await UniswapV3Router.deploy();

  const instance = await ethers.getContractAt(
    "UniswapV3Router",
    "0x32fFE78b774990279456466f0eb6A08cF096bca5"
  );
  // const instance = await UniswapV3Router.deploy();

  // console.log("sending nft to contract");
  // await nftManager
  //   .connect(whale)
  //   .transferFrom(whale.address, instance.address, nftId);

  // console.log("init");
  // await instance.initialize(
  //   config.gnosisSafe, // address _treasury,
  //   config.uniswapNFTPositionMangerAddr, // INonfungiblePositionManager _manager,
  //   poolAddress, // IUniswapV3Pool _pool,
  //   config.uniswapSwapRouter, // ISwapRouter _swapRouter,
  //   nftId // uint256 _poolId
  // );

  const weth = await ethers.getContractAt("IWETH", config.wethAddr);

  console.log("deposit 1 eth into the weth contract");
  await weth.connect(whale).deposit({ value: e18 });

  const balance = await weth.balanceOf(whale.address);
  console.log("weth balance of whale", balance);

  console.log("giving approval to contract");
  await weth.connect(whale).approve(instance.address, balance);

  // perform checkUpkeep
  const abiEncoder = new ethers.utils.AbiCoder();
  const execData = abiEncoder.encode(["uint256", "uint256"], [0, 0]);

  // console.log("exec data", checkData);
  console.log("weth tokens in LP before");
  console.log((await weth.balanceOf(poolAddress)).toString());

  console.log("execData", execData);

  console.log("executing lp strategy");
  await instance.connect(whale).execute(0, balance, execData);
  // console.log("peformData", ret.performData);

  console.log("weth tokens in LP after");
  console.log((await weth.balanceOf(poolAddress)).toString());

  console.log("weth tokens in whale after");
  console.log((await weth.balanceOf(whale.address)).toString());

  console.log("weth tokens in contract after");
  console.log((await weth.balanceOf(instance.address)).toString());

  // perform performUpkeep
  // await instance.connect(whale).performUpkeep(ret.performData);

  // console.log("lp tokens in treasury");
  // console.log((await lpToken.balanceOf(config.gnosisSafe)).toString());

  await instance.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
