// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IHelix — Solenoid Layer 2 yield matrix execution
/// @notice Phase 2 EVM interface; interlocks with Anchor helix program + treasury manifest
interface IHelix {
    event StrategyExecuted(bytes32 indexed poolId, uint256 deployedCapital);

    function deployStrategicCapital(
        bytes32 nodeId,
        bytes32 poolId,
        uint256 amount,
        bytes4 executionSelector,
        bytes calldata executionPayload
    ) external;
}
