// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEntropyProofVerifier} from "./verifiers/IEntropyProofVerifier.sol";
import {YieldSwarmNFT} from "./YieldSwarmNFT.sol";

/// @title MutationController
/// @notice ZK¹ + A¹ — gates weekly NFT mutations on verified entropy commitments.
/// @dev Greek layer ($D^1$) access control + Paradigm Shift ($PDs^1$) proof verification.
contract MutationController is AccessControl, ReentrancyGuard {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant AUTOMATION_ROLE = keccak256("AUTOMATION_ROLE");

    YieldSwarmNFT public immutable agentNft;
    IEntropyProofVerifier public entropyVerifier;

    uint256 public lastMutationWeek;
    uint256 public minEntropyQualityBps = 5000; // 50% minimum for mutation

    mapping(uint256 => bool) public consumedCommitments;
    mapping(uint256 => bytes32) public tokenLastBlockHash;

    event MutationRequested(uint256 indexed tokenId, uint256 commitment, bytes32 blockHash);
    event MutationExecuted(uint256 indexed tokenId, uint256 commitment, string newUri, uint8 tier);
    event WeeklyMutationTriggered(uint256 week);
    event EntropyProofRejected(uint256 indexed tokenId, uint256 commitment, string reason);

    error AlreadyMutatedThisWeek(uint256 week);
    error CommitmentConsumed(uint256 commitment);
    error ProofInvalid();
    error EntropyQualityTooLow(uint256 qualityBps, uint256 minimumBps);
    error TokenDoesNotExist(uint256 tokenId);

    constructor(address agentNftAddress, address verifierAddress, address admin) {
        agentNft = YieldSwarmNFT(agentNftAddress);
        entropyVerifier = IEntropyProofVerifier(verifierAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER_ROLE, admin);
    }

    function setEntropyVerifier(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entropyVerifier = IEntropyProofVerifier(verifier);
    }

    function setMinEntropyQualityBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bps <= 10_000, "max 100%");
        minEntropyQualityBps = bps;
    }

    /// @notice Chainlink Automation / weekly trigger (O¹ Oscillator).
    function triggerWeeklyMutation() external onlyRole(AUTOMATION_ROLE) {
        uint256 week = block.timestamp / 1 weeks;
        if (week <= lastMutationWeek) revert AlreadyMutatedThisWeek(week);
        lastMutationWeek = week;
        emit WeeklyMutationTriggered(week);
    }

    /// @notice Execute agent mutation after ZK entropy proof verification.
    /// @param entropyQualityBps off-chain computed quality score (0–10000) for routing gate.
    function executeAgentMutation(
        uint256 tokenId,
        uint8 newTier,
        string calldata newUri,
        uint256 commitment,
        bytes32 blockVerificationHash,
        uint256 entropyQualityBps,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC,
        uint256[3] calldata publicSignals
    ) external onlyRole(RELAYER_ROLE) nonReentrant {
        if (tokenId > type(uint128).max) revert TokenDoesNotExist(tokenId);
        try agentNft.ownerOf(tokenId) returns (address owner) {
            if (owner == address(0)) revert TokenDoesNotExist(tokenId);
        } catch {
            revert TokenDoesNotExist(tokenId);
        }

        if (entropyQualityBps < minEntropyQualityBps) {
            emit EntropyProofRejected(tokenId, commitment, "entropy quality below minimum");
            revert EntropyQualityTooLow(entropyQualityBps, minEntropyQualityBps);
        }

        if (consumedCommitments[commitment]) revert CommitmentConsumed(commitment);

        if (publicSignals[0] != commitment) {
            emit EntropyProofRejected(tokenId, commitment, "commitment mismatch");
            revert ProofInvalid();
        }

        bool ok = entropyVerifier.verifyEntropyProof(proofA, proofB, proofC, publicSignals);
        if (!ok) {
            emit EntropyProofRejected(tokenId, commitment, "verifier rejected proof");
            revert ProofInvalid();
        }

        consumedCommitments[commitment] = true;
        tokenLastBlockHash[tokenId] = blockVerificationHash;

        emit MutationRequested(tokenId, commitment, blockVerificationHash);

        bytes32 digest = keccak256(abi.encode(tokenId, newUri, commitment, blockVerificationHash));
        agentNft.controllerMutateUri(tokenId, newUri, digest, newTier);

        emit MutationExecuted(tokenId, commitment, newUri, newTier);
    }

    /// @notice Simplified relay for dev/testnet when oracle signature is handled off-chain.
    function executeAgentMutationWithAttestation(
        uint256 tokenId,
        uint8 newTier,
        string calldata newUri,
        uint256 commitment,
        bytes32 blockVerificationHash,
        uint256 entropyQualityBps
    ) external onlyRole(RELAYER_ROLE) nonReentrant {
        if (entropyQualityBps < minEntropyQualityBps) {
            revert EntropyQualityTooLow(entropyQualityBps, minEntropyQualityBps);
        }
        if (consumedCommitments[commitment]) revert CommitmentConsumed(commitment);

        consumedCommitments[commitment] = true;
        tokenLastBlockHash[tokenId] = blockVerificationHash;
        emit MutationRequested(tokenId, commitment, blockVerificationHash);

        bytes32 digest = keccak256(abi.encode(tokenId, newUri, commitment, blockVerificationHash));
        agentNft.controllerMutateUri(tokenId, newUri, digest, newTier);

        emit MutationExecuted(tokenId, commitment, newUri, newTier);
    }
}
