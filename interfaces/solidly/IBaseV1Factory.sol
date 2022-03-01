// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IBaseV1Factory {
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);

    function allPairs(uint256 index) external returns (address pair);

    function isPair(address pair) external returns (bool);
}
