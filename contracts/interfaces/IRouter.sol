// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRouter {
    function execute(
        uint256 tokenA,
        uint256 tokenB,
        bytes calldata extraData
    ) external;

    function tokens() external view returns (address tokenA, address tokenB);
}
