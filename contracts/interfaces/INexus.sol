// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title INexus — Solenoid Layer 1 governance authorization & routing
/// @notice Phase 2 EVM interface; interlocks with Rust Nexus runtime (services/nexus/)
interface INexus {
    struct SwarmNode {
        address agentAddress;
        bytes32 capabilityHash;
        uint256 operationalWeight;
        bool isActive;
    }

    event NodeRegistered(bytes32 indexed nodeId, address indexed agentAddress);
    event CommandRouted(bytes32 indexed nodeId, bytes4 indexed actionSelector, bytes data);

    function registerNode(bytes32 nodeId, address agent, bytes32 caps, uint256 weight) external;
    function routeCommand(bytes32 nodeId, bytes4 selector, bytes calldata data) external payable returns (bytes memory);
    function isNodeAuthorized(bytes32 nodeId) external view returns (bool);
}
