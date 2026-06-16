// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITokenStakingPool} from "./interfaces/ITokenStakingPool.sol";
import {IYieldSwarmNFT} from "./interfaces/IYieldSwarmNFT.sol";

/// @title TokenStakingPool
/// @notice Stake ETH against agent NFTs for mutation boost — ties stake to co-evolution.
contract TokenStakingPool is ITokenStakingPool {
    uint256 public constant MIN_STAKE = 0.01 ether;
    uint256 public constant MAX_BOOST_BPS = 2500; // +25% mutation quality cap
    uint256 public constant LOCK_PERIOD = 7 days;

    IYieldSwarmNFT public immutable nft;
    address public owner;
    address public mutationController;

    mapping(address => mapping(uint256 => StakePosition)) private _positions;
    mapping(uint256 => uint16) private _tokenBoostBps;

    error NotOwner();
    error NotTokenOwner();
    error BelowMinStake();
    error NoStake();
    error StillLocked();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address nftAddress, address initialOwner) {
        nft = IYieldSwarmNFT(nftAddress);
        owner = initialOwner;
    }

    function setMutationController(address controller) external onlyOwner {
        mutationController = controller;
    }

    function stake(uint256 tokenId) external payable {
        if (nft.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (msg.value < MIN_STAKE) revert BelowMinStake();

        uint16 boost = _computeBoost(msg.value, nft.mutationTier(tokenId));
        _positions[msg.sender][tokenId] = StakePosition({
            amount: msg.value,
            stakedAt: block.timestamp,
            unlockAt: block.timestamp + LOCK_PERIOD,
            mutationBoostBps: boost
        });
        _tokenBoostBps[tokenId] = boost;

        emit Staked(msg.sender, tokenId, msg.value, boost);
        emit BoostApplied(tokenId, boost);
    }

    function unstake(uint256 tokenId) external {
        StakePosition memory pos = _positions[msg.sender][tokenId];
        if (pos.amount == 0) revert NoStake();
        if (block.timestamp < pos.unlockAt) revert StillLocked();

        delete _positions[msg.sender][tokenId];
        _tokenBoostBps[tokenId] = 0;

        (bool ok,) = msg.sender.call{value: pos.amount}("");
        if (!ok) revert TransferFailed();

        emit Unstaked(msg.sender, tokenId, pos.amount);
    }

    function mutationBoostBps(uint256 tokenId) external view returns (uint16) {
        return _tokenBoostBps[tokenId];
    }

    function positionOf(address staker, uint256 tokenId) external view returns (StakePosition memory) {
        return _positions[staker][tokenId];
    }

    function _computeBoost(uint256 amount, uint8 tier) internal pure returns (uint16) {
        uint256 base = (amount / MIN_STAKE) * 100; // 1% per MIN_STAKE unit
        uint256 tierMult = 100 + uint256(tier) * 25;
        uint256 boost = (base * tierMult) / 100;
        if (boost > MAX_BOOST_BPS) boost = MAX_BOOST_BPS;
        return uint16(boost);
    }
}
