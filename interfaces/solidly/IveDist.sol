// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

// NOT SURE WHAT THSI CONTRACT DOES, but you claim stuff
interface IveDist {
    function claimable(uint256 _tokenId) external view returns (uint256);

    function claim(uint256 _tokenId) external returns (uint256);

    function claim_many(uint256[] memory _tokenIds) external returns (bool);
}
