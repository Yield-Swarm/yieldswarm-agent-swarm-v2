// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IYieldSwarmNFT
/// @notice Mutating agent NFT — Greek layer boundary for on-chain identity.
interface IYieldSwarmNFT {
    struct AgentGenome {
        uint16 aggressionBps;
        uint16 providerLoyaltyBps;
        uint16 riskAppetiteBps;
        uint16 creditBufferBps;
        uint16 rebalanceBiasBps;
        uint8 tier; // 0 bronze .. 4 apex
        uint32 mutationEpoch;
        uint64 lastMutationAt;
    }

    event AgentMinted(uint256 indexed tokenId, address indexed owner, uint8 tier);
    event GenomeUpdated(uint256 indexed tokenId, uint32 mutationEpoch, bytes32 genomeHash);
    event AgentFused(uint256 indexed burnedId, uint256 indexed survivorId, uint8 newTier);

    function ownerOf(uint256 tokenId) external view returns (address);
    function genomeOf(uint256 tokenId) external view returns (AgentGenome memory);
    function mutationTier(uint256 tokenId) external view returns (uint8);
    function totalSupply() external view returns (uint256);

    function mint(address to, uint8 tier) external returns (uint256 tokenId);
    function updateGenome(uint256 tokenId, AgentGenome calldata genome, bytes32 genomeHash) external;
    function fuse(uint256 tokenIdA, uint256 tokenIdB) external returns (uint256 survivorId);
}
