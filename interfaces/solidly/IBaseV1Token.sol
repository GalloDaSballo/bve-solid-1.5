// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IBaseV1Token {
    function minter() external view returns (address);

    function approve(address spender, uint256 value) external returns (bool);

    function mint(address, uint256) external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function transfer(
        address,
        address,
        uint256
    ) external returns (bool);
}
