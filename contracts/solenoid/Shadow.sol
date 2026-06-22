// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IShadow} from "../interfaces/IShadow.sol";

/// @title Shadow — Solenoid Layer 3: white-hat privacy obfuscation (dark-pool intents)
/// @dev Commit-reveal blinded execution intents; interlocks with ZK-Swarm mutation batches.
contract Shadow is IShadow {
    address public immutable deploymentController;

    mapping(bytes32 => bool) private stateCommitments;
    mapping(bytes32 => uint256) public blindedExpirations;

    error AlreadyCommitted();
    error CommitmentMissing();
    error MaturationPending();
    error ProofMismatch();

    constructor() {
        deploymentController = msg.sender;
    }

    function submitBlindedIntent(bytes32 stateHash, uint256 executionDelay) external override {
        if (stateCommitments[stateHash]) revert AlreadyCommitted();

        stateCommitments[stateHash] = true;
        blindedExpirations[stateHash] = block.timestamp + executionDelay;

        emit CommitmentBlinded(stateHash, blindedExpirations[stateHash]);
    }

    function revealAndSettleIntent(
        bytes32 stateHash,
        bytes32 salt,
        bytes calldata actualPayload
    ) external override returns (bool) {
        if (!stateCommitments[stateHash]) revert CommitmentMissing();
        if (block.timestamp < blindedExpirations[stateHash]) revert MaturationPending();

        bytes32 computedHash = keccak256(abi.encodePacked(salt, actualPayload, msg.sender));
        if (computedHash != stateHash) revert ProofMismatch();

        stateCommitments[stateHash] = false;
        emit CommitmentSettled(stateHash);

        return true;
    }

    function isCommitted(bytes32 stateHash) external view returns (bool) {
        return stateCommitments[stateHash];
    }
}
