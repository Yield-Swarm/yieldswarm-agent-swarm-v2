// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IShadow — Solenoid Layer 3 ZK blinded intent commitments
/// @notice Phase 2 EVM interface; interlocks with Arena/Shadow Chain + ZK-Swarm proofs
interface IShadow {
    event CommitmentBlinded(bytes32 indexed internalStateHash, uint256 executionHorizon);
    event CommitmentSettled(bytes32 indexed internalStateHash);

    function submitBlindedIntent(bytes32 stateHash, uint256 executionDelay) external;
    function revealAndSettleIntent(bytes32 stateHash, bytes32 salt, bytes calldata actualPayload) external returns (bool);
}
