// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../erc20/IERC20.sol";

interface IBridgedToken is IERC20 {
    function owner() external view returns (address);

    function Swapin(
        bytes32 txhash,
        address account,
        uint256 amount
    ) external returns (bool);
}
