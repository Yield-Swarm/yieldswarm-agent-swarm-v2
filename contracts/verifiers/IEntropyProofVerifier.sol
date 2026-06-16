// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEntropyProofVerifier
/// @notice ZK¹ interface — Groth16 verifier for entropy_proof.circom public signals.
interface IEntropyProofVerifier {
    /// @notice Verify a Groth16 proof against public signals.
    /// @param publicSignals [commitment, vramMaxScaled, tempMaxScaled]
    function verifyEntropyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external view returns (bool);
}
