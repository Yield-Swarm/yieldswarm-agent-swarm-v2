// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEntropyProofVerifier
/// @notice Groth16 verifier interface for entropy seed proofs (ZK¹ layer).
interface IEntropyProofVerifier {
    /// @dev ZK error codes (D¹ Task 8) — mirrored off-chain in ZK_ERROR_CODES
    error InvalidProof();
    error InvalidPublicSignal();
    error VerifierNotConfigured();

    event ProofVerified(uint256 indexed entropySeed, address indexed prover);

    function verifyEntropyProof(
        uint256[2] calldata pi_a,
        uint256[2][2] calldata pi_b,
        uint256[2] calldata pi_c,
        uint256[1] calldata pubSignals
    ) external view returns (bool);

    function circuitVersion() external view returns (string memory);
}
