// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYieldSwarmNFT} from "./interfaces/IYieldSwarmNFT.sol";

/// @title YieldSwarmNFT
/// @notice Mutating Agent NFT — Greek (isolated identity) + Paradigm Shift (co-evolution).
/// @dev Minimal ERC-721 implementation without external dependencies.
contract YieldSwarmNFT is IYieldSwarmNFT {
    string public constant name = "YieldSwarm Agent";
    string public constant symbol = "YSA";
    uint256 public constant MAX_TIER = 4;

    address public owner;
    address public mutationController;
    address public leasingContract;

    uint256 private _nextTokenId = 1;
    uint256 private _totalSupply;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(uint256 => AgentGenome) private _genomes;
    mapping(uint256 => bytes32) private _genomeHashes;

    error NotOwner();
    error NotAuthorized();
    error InvalidTier();
    error TokenNotFound();
    error NotTokenOwner();
    error FusionTierMismatch();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyMutationController() {
        if (msg.sender != mutationController) revert NotAuthorized();
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
    }

    function setMutationController(address controller) external onlyOwner {
        mutationController = controller;
    }

    function setLeasingContract(address leasing) external onlyOwner {
        leasingContract = leasing;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert TokenNotFound();
        return tokenOwner;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[account];
    }

    function genomeOf(uint256 tokenId) external view returns (AgentGenome memory) {
        _requireMinted(tokenId);
        return _genomes[tokenId];
    }

    function genomeHashOf(uint256 tokenId) external view returns (bytes32) {
        _requireMinted(tokenId);
        return _genomeHashes[tokenId];
    }

    function mutationTier(uint256 tokenId) external view returns (uint8) {
        _requireMinted(tokenId);
        return _genomes[tokenId].tier;
    }

    function mint(address to, uint8 tier) external onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (tier > MAX_TIER) revert InvalidTier();

        tokenId = _nextTokenId++;
        _totalSupply++;
        _owners[tokenId] = to;
        _balances[to]++;

        _genomes[tokenId] = AgentGenome({
            aggressionBps: 5000,
            providerLoyaltyBps: 5000,
            riskAppetiteBps: 4000,
            creditBufferBps: 6000,
            rebalanceBiasBps: 5000,
            tier: tier,
            mutationEpoch: 0,
            lastMutationAt: uint64(block.timestamp)
        });
        _genomeHashes[tokenId] = keccak256(abi.encode(tokenId, tier, block.timestamp));

        emit AgentMinted(tokenId, to, tier);
        emit Transfer(address(0), to, tokenId);
    }

    function updateGenome(
        uint256 tokenId,
        AgentGenome calldata genome,
        bytes32 genomeHash
    ) external onlyMutationController {
        _requireMinted(tokenId);
        if (genome.tier > MAX_TIER) revert InvalidTier();
        _genomes[tokenId] = genome;
        _genomeHashes[tokenId] = genomeHash;
        emit GenomeUpdated(tokenId, genome.mutationEpoch, genomeHash);
    }

    /// @notice Fuse two agents — survivor inherits higher tier + averaged genome.
    function fuse(uint256 tokenIdA, uint256 tokenIdB) external returns (uint256 survivorId) {
        if (tokenIdA == tokenIdB) revert FusionTierMismatch();
        address ownerA = ownerOf(tokenIdA);
        address ownerB = ownerOf(tokenIdB);
        if (msg.sender != ownerA || msg.sender != ownerB) revert NotTokenOwner();

        AgentGenome memory ga = _genomes[tokenIdA];
        AgentGenome memory gb = _genomes[tokenIdB];
        uint8 newTier = ga.tier >= gb.tier ? ga.tier : gb.tier;
        if (newTier < MAX_TIER) newTier += 1;

        _burn(tokenIdA);
        survivorId = tokenIdB;

        _genomes[survivorId] = AgentGenome({
            aggressionBps: uint16((uint256(ga.aggressionBps) + gb.aggressionBps) / 2),
            providerLoyaltyBps: uint16((uint256(ga.providerLoyaltyBps) + gb.providerLoyaltyBps) / 2),
            riskAppetiteBps: uint16((uint256(ga.riskAppetiteBps) + gb.riskAppetiteBps) / 2),
            creditBufferBps: uint16((uint256(ga.creditBufferBps) + gb.creditBufferBps) / 2),
            rebalanceBiasBps: uint16((uint256(ga.rebalanceBiasBps) + gb.rebalanceBiasBps) / 2),
            tier: newTier,
            mutationEpoch: ga.mutationEpoch > gb.mutationEpoch ? ga.mutationEpoch : gb.mutationEpoch,
            lastMutationAt: uint64(block.timestamp)
        });
        _genomeHashes[survivorId] = keccak256(abi.encode(survivorId, newTier, block.timestamp));

        emit AgentFused(tokenIdA, survivorId, newTier);
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (to == tokenOwner) revert NotAuthorized();
        if (msg.sender != tokenOwner && !isApprovedForAll(tokenOwner, msg.sender)) {
            revert NotAuthorized();
        }
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        _requireMinted(tokenId);
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (ownerOf(tokenId) != from) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddress();

        delete _tokenApprovals[tokenId];
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address tokenOwner = ownerOf(tokenId);
        delete _tokenApprovals[tokenId];
        delete _genomes[tokenId];
        delete _genomeHashes[tokenId];
        _balances[tokenOwner]--;
        delete _owners[tokenId];
        _totalSupply--;
        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _requireMinted(uint256 tokenId) internal view {
        if (_owners[tokenId] == address(0)) revert TokenNotFound();
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(tokenOwner, spender));
    }
}
