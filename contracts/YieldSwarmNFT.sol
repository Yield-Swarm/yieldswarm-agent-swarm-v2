// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title YieldSwarmNFT
/// @notice Greek layer ($D^1$) — immutable agent identity boundary with oracle-gated mutable URIs.
/// @dev URI updates are accepted only from authorized oracles presenting a validated callback digest.
contract YieldSwarmNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using MessageHashUtils for bytes32;

    uint256 private _nextTokenId;

    /// @notice Authorized oracle signers (multisig-style allowlist).
    mapping(address => bool) public authorizedOracles;

    /// @notice Replay protection for oracle callbacks.
    mapping(bytes32 => bool) public consumedCallbackDigests;

    /// @notice Agent tier encoded at mint (drives downstream risk gates).
    mapping(uint256 => uint8) public agentTier;

    /// @notice Last validated oracle digest per token.
    mapping(uint256 => bytes32) public lastValidatedDigest;

    /// @notice ZK-gated mutation controller (A¹ Ancestral living memory).
    address public mutationController;

    error NotAuthorizedOracle(address caller);
    error NotAuthorizedMutationController(address caller);
    error CallbackAlreadyConsumed(bytes32 digest);
    error InvalidOracleSignature();
    error InvalidTier(uint8 tier);
    error TokenDoesNotExist(uint256 tokenId);

    event OracleAuthorized(address indexed oracle, bool authorized);
    event AgentMinted(uint256 indexed tokenId, address indexed to, uint8 tier, string initialUri);
    event UriUpdatedByOracle(
        uint256 indexed tokenId,
        address indexed oracle,
        string newUri,
        bytes32 callbackDigest
    );
    event UriUpdatedByController(
        uint256 indexed tokenId,
        address indexed controller,
        string newUri,
        bytes32 entropyDigest,
        uint8 newTier
    );

    constructor(address initialOwner) ERC721("YieldSwarm Agent", "YSAGENT") Ownable(initialOwner) {
        authorizedOracles[initialOwner] = true;
    }

    /// @inheritdoc ERC721URIStorage
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireOwned(tokenId);
        return super.tokenURI(tokenId);
    }

    function setOracleAuthorized(address oracle, bool authorized) external onlyOwner {
        authorizedOracles[oracle] = authorized;
        emit OracleAuthorized(oracle, authorized);
    }

    function setMutationController(address controller) external onlyOwner {
        mutationController = controller;
    }

    /// @notice ZK-verified mutation path — only MutationController after entropy proof.
    function controllerMutateUri(
        uint256 tokenId,
        string calldata newUri,
        bytes32 entropyDigest,
        uint8 newTier
    ) external nonReentrant {
        if (msg.sender != mutationController) revert NotAuthorizedMutationController(msg.sender);
        if (!_exists(tokenId)) revert TokenDoesNotExist(tokenId);
        if (newTier == 0 || newTier > 5) revert InvalidTier(newTier);
        if (consumedCallbackDigests[entropyDigest]) revert CallbackAlreadyConsumed(entropyDigest);

        consumedCallbackDigests[entropyDigest] = true;
        lastValidatedDigest[tokenId] = entropyDigest;
        agentTier[tokenId] = newTier;
        _setTokenURI(tokenId, newUri);
        emit UriUpdatedByController(tokenId, msg.sender, newUri, entropyDigest, newTier);
    }

    /// @notice Mint a new agent NFT with tier metadata.
    function mintAgent(address to, uint8 tier, string calldata initialUri) external onlyOwner returns (uint256 tokenId) {
        if (tier == 0 || tier > 5) revert InvalidTier(tier);
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        agentTier[tokenId] = tier;
        _setTokenURI(tokenId, initialUri);
        emit AgentMinted(tokenId, to, tier, initialUri);
    }

    /// @notice Oracle callback — updates URI only after ECDSA validation of the callback payload.
    /// @param tokenId Agent token to mutate.
    /// @param newUri Validated metadata URI (IPFS/Arweave/https).
    /// @param callbackDigest Unique digest for replay protection.
    /// @param signature Oracle signature over keccak256(abi.encode(tokenId, newUri, callbackDigest, block.chainid)).
    function oracleUpdateUri(
        uint256 tokenId,
        string calldata newUri,
        bytes32 callbackDigest,
        bytes calldata signature
    ) external nonReentrant {
        if (!_exists(tokenId)) revert TokenDoesNotExist(tokenId);
        if (!authorizedOracles[msg.sender]) revert NotAuthorizedOracle(msg.sender);
        if (consumedCallbackDigests[callbackDigest]) revert CallbackAlreadyConsumed(callbackDigest);

        bytes32 payloadHash = keccak256(abi.encode(tokenId, newUri, callbackDigest, block.chainid));
        bytes32 ethSigned = payloadHash.toEthSignedMessageHash();
        address signer = ECDSA.recover(ethSigned, signature);
        if (!authorizedOracles[signer]) revert InvalidOracleSignature();

        consumedCallbackDigests[callbackDigest] = true;
        lastValidatedDigest[tokenId] = callbackDigest;
        _setTokenURI(tokenId, newUri);
        emit UriUpdatedByOracle(tokenId, msg.sender, newUri, callbackDigest);
    }

    function getAgentTier(uint256 tokenId) external view returns (uint8) {
        _requireOwned(tokenId);
        return agentTier[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _exists(uint256 tokenId) private view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
