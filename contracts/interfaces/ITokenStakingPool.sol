// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ITokenStakingPool
/// @notice Staking with mutation boost — ties economic stake to co-evolution.
interface ITokenStakingPool {
    struct StakePosition {
        uint256 amount;
        uint256 stakedAt;
        uint256 unlockAt;
        uint16 mutationBoostBps; // additive boost to mutation quality
    }

    event Staked(address indexed staker, uint256 indexed tokenId, uint256 amount, uint16 boostBps);
    event Unstaked(address indexed staker, uint256 indexed tokenId, uint256 amount);
    event BoostApplied(uint256 indexed tokenId, uint16 mutationBoostBps);

    function stake(uint256 tokenId) external payable;
    function unstake(uint256 tokenId) external;
    function mutationBoostBps(uint256 tokenId) external view returns (uint16);
    function positionOf(address staker, uint256 tokenId) external view returns (StakePosition memory);
}
