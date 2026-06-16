// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMutationController} from "./interfaces/IMutationController.sol";
import {IYieldSwarmNFT} from "./interfaces/IYieldSwarmNFT.sol";
import {IEntropyProofVerifier} from "./interfaces/IEntropyProofVerifier.sol";

/// @title MutationController
/// @notice Weekly mutation engine with ZK-verified entropy (5-layer helical integration).
contract MutationController is IMutationController {
    uint256 public constant DEFAULT_INTERVAL = 7 days;
    uint256 public constant MAX_INTERVAL = 30 days;

    IYieldSwarmNFT public immutable nft;
    IEntropyProofVerifier public entropyVerifier;
    address public owner;
    address public oracleBridge;
    address public automationForwarder;
    address public zkProverRole;

    uint256 public mutationInterval = DEFAULT_INTERVAL;
    uint256 public epochCounter;
    bool public zkProofRequired = true;

    mapping(uint256 => uint32) public lastMutationEpoch;
    mapping(uint256 => bytes32) public scheduledEntropy;
    mapping(uint256 => bool) public mutationPending;

    // D¹ Task 7 — ZK access control
    mapping(address => bool) public proofSubmitters;

    // ---- D¹ Task 8: ZK error codes ----
    error NotOwner();
    error NotAuthorized();
    error NotProofSubmitter();
    error MutationNotReady();
    error MutationNotScheduled();
    error InvalidInterval();
    error InvalidEntropyProof();
    error EntropySeedMismatch();
    error ZKProofRequired();
    error ZKVerifierNotSet();

    event ZKProofVerified(uint256 indexed tokenId, uint256 entropySeed, address prover);
    event EntropyVerifierUpdated(address indexed verifier);
    event ZKProofRequiredUpdated(bool required);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOracleOrAutomation() {
        if (msg.sender != oracleBridge && msg.sender != automationForwarder && msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyProofSubmitter() {
        if (!proofSubmitters[msg.sender] && msg.sender != owner && msg.sender != zkProverRole) {
            revert NotProofSubmitter();
        }
        _;
    }

    constructor(address nftAddress, address initialOwner) {
        nft = IYieldSwarmNFT(nftAddress);
        owner = initialOwner;
        proofSubmitters[initialOwner] = true;
    }

    function setEntropyVerifier(address verifier) external onlyOwner {
        entropyVerifier = IEntropyProofVerifier(verifier);
        emit EntropyVerifierUpdated(verifier);
    }

    function setZkProofRequired(bool required) external onlyOwner {
        zkProofRequired = required;
        emit ZKProofRequiredUpdated(required);
    }

    function setProofSubmitter(address account, bool allowed) external onlyOwner {
        proofSubmitters[account] = allowed;
    }

    function setZkProverRole(address prover) external onlyOwner {
        zkProverRole = prover;
    }

    function setOracleBridge(address bridge) external onlyOwner {
        oracleBridge = bridge;
    }

    function setAutomationForwarder(address forwarder) external onlyOwner {
        automationForwarder = forwarder;
    }

    function setMutationInterval(uint256 interval) external onlyOwner {
        if (interval < 1 days || interval > MAX_INTERVAL) revert InvalidInterval();
        mutationInterval = interval;
    }

    function canMutate(uint256 tokenId) public view returns (bool) {
        IYieldSwarmNFT.AgentGenome memory genome = nft.genomeOf(tokenId);
        return block.timestamp >= uint256(genome.lastMutationAt) + mutationInterval;
    }

    function scheduleMutation(uint256 tokenId, bytes32 entropySeed) external onlyOracleOrAutomation {
        if (!canMutate(tokenId)) {
            emit MutationSkipped(tokenId, "interval_not_elapsed");
            return;
        }
        epochCounter++;
        lastMutationEpoch[tokenId] = uint32(epochCounter);
        scheduledEntropy[tokenId] = entropySeed;
        mutationPending[tokenId] = true;
        emit MutationScheduled(tokenId, uint32(epochCounter), entropySeed);
    }

    function executeMutation(
        uint256 tokenId,
        bytes32 newGenomeHash,
        IYieldSwarmNFT.AgentGenome calldata genome
    ) external onlyOracleOrAutomation {
        if (zkProofRequired) revert ZKProofRequired();
        _executeMutation(tokenId, newGenomeHash, genome);
    }

    /// @notice PDs¹ Task 41 — mutation requires valid ZK proof of entropy seed.
    function executeMutationWithProof(
        uint256 tokenId,
        bytes32 newGenomeHash,
        IYieldSwarmNFT.AgentGenome calldata genome,
        uint256[2] calldata pi_a,
        uint256[2][2] calldata pi_b,
        uint256[2] calldata pi_c,
        uint256[1] calldata pubSignals
    ) external onlyProofSubmitter {
        if (!mutationPending[tokenId]) revert MutationNotScheduled();
        if (address(entropyVerifier) == address(0)) revert ZKVerifierNotSet();

        bool valid = entropyVerifier.verifyEntropyProof(pi_a, pi_b, pi_c, pubSignals);
        if (!valid) revert InvalidEntropyProof();

        bytes32 seedFromProof = bytes32(pubSignals[0]);
        if (seedFromProof != scheduledEntropy[tokenId]) revert EntropySeedMismatch();

        emit ZKProofVerified(tokenId, pubSignals[0], msg.sender);
        _executeMutation(tokenId, newGenomeHash, genome);
    }

    function _executeMutation(
        uint256 tokenId,
        bytes32 newGenomeHash,
        IYieldSwarmNFT.AgentGenome calldata genome
    ) internal {
        if (!mutationPending[tokenId]) revert MutationNotScheduled();

        IYieldSwarmNFT.AgentGenome memory updated = genome;
        updated.mutationEpoch = lastMutationEpoch[tokenId];
        updated.lastMutationAt = uint64(block.timestamp);

        nft.updateGenome(tokenId, updated, newGenomeHash);
        mutationPending[tokenId] = false;
        delete scheduledEntropy[tokenId];

        emit MutationExecuted(tokenId, lastMutationEpoch[tokenId], newGenomeHash);
    }

    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256 supply = nft.totalSupply();
        uint256[] memory ready = new uint256[](supply);
        uint256 count;

        for (uint256 i = 1; i <= supply && count < 32; i++) {
            try nft.ownerOf(i) returns (address) {
                if (canMutate(i) && !mutationPending[i]) {
                    ready[count++] = i;
                }
            } catch {}
        }

        if (count == 0) return (false, "");
        uint256[] memory batch = new uint256[](count);
        for (uint256 j = 0; j < count; j++) batch[j] = ready[j];
        return (true, abi.encode(batch));
    }

    function performUpkeep(bytes calldata performData) external onlyOracleOrAutomation {
        uint256[] memory tokenIds = abi.decode(performData, (uint256[]));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            bytes32 seed = keccak256(abi.encode(block.prevrandao, tokenIds[i], block.timestamp));
            scheduleMutation(tokenIds[i], seed);
        }
    }
}
