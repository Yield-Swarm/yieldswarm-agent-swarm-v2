// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAgentTierReader {
    function getAgentTier(uint256 tokenId) external view returns (uint8);
}

/// @title TokenStakingPool — stake Agent NFTs for routing weight boosts
contract TokenStakingPool is Ownable, ReentrancyGuard {
  struct StakeInfo {
    address owner;
    uint256 stakedAt;
    uint256 weight;
  }

  IERC721 public immutable agentNFT;
  IAgentTierReader public tierReader;

  mapping(uint256 => StakeInfo) public stakes;
  mapping(address => uint256[]) private _ownerStakes;

  uint256 public totalWeight;
  uint256 public baseWeightBps = 10_000;

  event Staked(address indexed owner, uint256 indexed tokenId, uint256 weight);
  event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 weight);

  constructor(address _agentNFT) Ownable(msg.sender) {
    agentNFT = IERC721(_agentNFT);
    tierReader = IAgentTierReader(_agentNFT);
  }

  function stake(uint256 tokenId) external nonReentrant {
    require(agentNFT.ownerOf(tokenId) == msg.sender, "Not owner");
    require(stakes[tokenId].owner == address(0), "Already staked");

    agentNFT.transferFrom(msg.sender, address(this), tokenId);

    uint8 tier = tierReader.getAgentTier(tokenId);
    uint256 weight = baseWeightBps + uint256(tier) * 500;

    stakes[tokenId] = StakeInfo({ owner: msg.sender, stakedAt: block.timestamp, weight: weight });
    _ownerStakes[msg.sender].push(tokenId);
    totalWeight += weight;

    emit Staked(msg.sender, tokenId, weight);
  }

  function unstake(uint256 tokenId) external nonReentrant {
    StakeInfo memory info = stakes[tokenId];
    require(info.owner == msg.sender, "Not staker");

    uint256 weight = info.weight;
    delete stakes[tokenId];
    totalWeight -= weight;

    agentNFT.transferFrom(address(this), msg.sender, tokenId);
    emit Unstaked(msg.sender, tokenId, weight);
  }

  function getStakeWeight(uint256 tokenId) external view returns (uint256) {
    return stakes[tokenId].weight;
  }

  function getOwnerStakes(address owner) external view returns (uint256[] memory) {
    return _ownerStakes[owner];
  }
}
