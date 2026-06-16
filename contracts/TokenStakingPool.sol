// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {YieldSwarmNFT} from "./YieldSwarmNFT.sol";

/// @title TokenStakingPool
/// @notice S¹ Sovereign — stake Agent NFTs for routing weight boosts.
contract TokenStakingPool is Ownable, ReentrancyGuard {
    struct StakeInfo {
        address owner;
        uint256 stakedAt;
        uint256 weight;
    }

    YieldSwarmNFT public immutable agentNft;

    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256[]) private _ownerStakes;
    uint256 public totalWeight;
    uint256 public baseWeightBps = 10_000;

    event Staked(address indexed owner, uint256 indexed tokenId, uint256 weight);
    event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 weight);

    error NotTokenOwner();
    error AlreadyStaked();
    error NotStaker();

    constructor(address agentNftAddress, address initialOwner) Ownable(initialOwner) {
        agentNft = YieldSwarmNFT(agentNftAddress);
    }

    function stake(uint256 tokenId) external nonReentrant {
        if (IERC721(address(agentNft)).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (stakes[tokenId].owner != address(0)) revert AlreadyStaked();

        IERC721(address(agentNft)).transferFrom(msg.sender, address(this), tokenId);

        uint8 tier = agentNft.getAgentTier(tokenId);
        uint256 weight = baseWeightBps + uint256(tier) * 500;

        stakes[tokenId] = StakeInfo({ owner: msg.sender, stakedAt: block.timestamp, weight: weight });
        _ownerStakes[msg.sender].push(tokenId);
        totalWeight += weight;

        emit Staked(msg.sender, tokenId, weight);
    }

    function unstake(uint256 tokenId) external nonReentrant {
        StakeInfo memory info = stakes[tokenId];
        if (info.owner != msg.sender) revert NotStaker();

        uint256 weight = info.weight;
        delete stakes[tokenId];
        totalWeight -= weight;

        IERC721(address(agentNft)).transferFrom(address(this), msg.sender, tokenId);
        emit Unstaked(msg.sender, tokenId, weight);
    }

    function getStakeWeight(uint256 tokenId) external view returns (uint256) {
        return stakes[tokenId].weight;
    }

    function getOwnerStakes(address owner) external view returns (uint256[] memory) {
        return _ownerStakes[owner];
    }
}
