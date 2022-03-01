// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IBaseV1Minter {
    function update_period() external returns (uint256);
}
