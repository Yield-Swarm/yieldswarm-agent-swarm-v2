// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEntropyProofVerifier} from "./IEntropyProofVerifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title EntropyProofVerifier
/// @notice ZK¹ dev/testnet verifier — validates public signal structure and commitment replay protection.
/// @dev Replace with snarkjs-exported Groth16 verifier on mainnet (scripts/zk-export-verifier.sh).
contract EntropyProofVerifier is IEntropyProofVerifier, Ownable {
    mapping(uint256 => bool) public verifiedCommitments;

    event CommitmentVerified(uint256 indexed commitment, uint256 vramMaxScaled, uint256 tempMaxScaled);

    error InvalidPublicSignals();
    error CommitmentAlreadyVerified(uint256 commitment);
    error ProofVerificationFailed();

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc IEntropyProofVerifier
    function verifyEntropyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external view override returns (bool) {
        // Structural validation — full pairing check lives in exported Groth16 verifier.
        if (publicSignals[0] == 0) revert InvalidPublicSignals();
        if (publicSignals[1] == 0 || publicSignals[2] == 0) revert InvalidPublicSignals();

        // Non-zero proof points required (dev verifier rejects empty proofs).
        if (a[0] == 0 && a[1] == 0 && b[0][0] == 0 && c[0] == 0) {
            return false;
        }

        // Silence unused warnings in dev mode.
        a;
        b;
        c;

        return true;
    }

    /// @notice Record a verified commitment on-chain (called by MutationController after verify).
    function recordVerifiedCommitment(uint256 commitment, uint256 vramMaxScaled, uint256 tempMaxScaled)
        external
        onlyOwner
    {
        if (verifiedCommitments[commitment]) revert CommitmentAlreadyVerified(commitment);
        verifiedCommitments[commitment] = true;
        emit CommitmentVerified(commitment, vramMaxScaled, tempMaxScaled);
    }

    /// @notice Dev/testnet path — owner attests commitment after off-chain snarkjs verify.
    function attestCommitment(uint256 commitment, uint256 vramMaxScaled, uint256 tempMaxScaled) external onlyOwner {
        if (commitment == 0) revert InvalidPublicSignals();
        if (verifiedCommitments[commitment]) revert CommitmentAlreadyVerified(commitment);
        verifiedCommitments[commitment] = true;
        emit CommitmentVerified(commitment, vramMaxScaled, tempMaxScaled);
    }

    function isCommitmentVerified(uint256 commitment) external view returns (bool) {
        return verifiedCommitments[commitment];
    }
}
