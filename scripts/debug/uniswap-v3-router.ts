import * as config from "../constants";
import { ethers } from "hardhat";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";

async function main() {
  const UniswapV3Router = await ethers.getContractFactory("UniswapV3Router");
  const instance = await UniswapV3Router.deploy();

  // impersonate ARTH whale
  const address = "0x6357EDbfE5aDA570005ceB8FAd3139eF5A8863CC";
  await helpers.impersonateAccount(address);
  await helpers.setBalance(address, "0x56BC75E2D63100000");

  const nftManager = "0xdf34bad1d3b16c8f28c9cf95f15001949243a038";
  const nftId = 100;

  console.log("init");
  await instance.initialize(
    config.gnosisSafe, // address _treasury,
    nftManager, // INonfungiblePositionManager _manager,
    nftId, // uint256 _poolId,
    config.arthAddr, // IERC20 _token0,
    config.mahaAddr // IERC20 _token1
  );

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

  // console.log("lp tokens in treasury");
  // console.log((await lpToken.balanceOf(config.gnosisSafe)).toString());

  // perform performUpkeep
  console.log("executing lp strategy");
  await instance.connect(whale).performUpkeep(ret.performData);

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
