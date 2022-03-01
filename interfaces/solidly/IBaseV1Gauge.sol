// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IBaseV1Gauge {
    function stake() external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function deposit(uint256 amount, uint256 tokenId) external;

    function withdrawAll() external;

    function withdraw(uint256 amount) external;

    function earned(address token, address account)
        external
        view
        returns (uint256);

    function getReward(address account, address[] memory tokens) external;

    function derivedBalance(address account) external view returns (uint256);

    function rewardRate(address) external view returns (uint256);

    function rewardPerToken(address token) external view returns (uint256);

    function rewardPerTokenStored(address token)
        external
        view
        returns (uint256);

    function userRewardPerTokenStored(address token, address account)
        external
        view
        returns (uint256);

    function lastTimeRewardApplicable(address token)
        external
        view
        returns (uint256);

    function lastUpdateTime(address token) external view returns (uint256);

    function periodFinish(address token) external view returns (uint256);

    function checkpoints(address, uint256)
        external
        view
        returns (uint256, uint256);

    function numCheckpoints(address) external view returns (uint256);

    function getPriorBalanceIndex(address, uint256)
        external
        view
        returns (uint256);

    function getPriorRewardPerToken(address, uint256)
        external
        view
        returns (uint256, uint256);
}
