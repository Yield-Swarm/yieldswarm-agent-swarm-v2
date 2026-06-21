// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INexus} from "../interfaces/INexus.sol";

/// @title Nexus — Solenoid Layer 1: governance authorization & routing engine
/// @dev Unified control plane for 14-Council execution vectors and swarm node registry.
contract Nexus is INexus {
    address public governanceCouncil;
    mapping(bytes32 => SwarmNode) public swarmRegistry;
    mapping(address => bool) public authorizedCallers;

    error NotCouncil();
    error NodeAlreadyRegistered();
    error NodeInactive();
    error UnauthorizedCaller();
    error ExecutionFailed();

    modifier onlyCouncil() {
        if (msg.sender != governanceCouncil) revert NotCouncil();
        _;
    }

    constructor(address _governanceCouncil) {
        governanceCouncil = _governanceCouncil;
        authorizedCallers[msg.sender] = true;
    }

    function registerNode(
        bytes32 nodeId,
        address agent,
        bytes32 caps,
        uint256 weight
    ) external override onlyCouncil {
        if (swarmRegistry[nodeId].agentAddress != address(0)) revert NodeAlreadyRegistered();

        swarmRegistry[nodeId] = SwarmNode({
            agentAddress: agent,
            capabilityHash: caps,
            operationalWeight: weight,
            isActive: true
        });

        emit NodeRegistered(nodeId, agent);
    }

    function routeCommand(
        bytes32 nodeId,
        bytes4 selector,
        bytes calldata data
    ) external payable override returns (bytes memory) {
        SwarmNode memory node = swarmRegistry[nodeId];
        if (!node.isActive) revert NodeInactive();
        if (!authorizedCallers[msg.sender]) revert UnauthorizedCaller();

        (bool success, bytes memory result) = node.agentAddress.call{value: msg.value}(
            abi.encodeWithSelector(selector, data)
        );
        if (!success) revert ExecutionFailed();

        emit CommandRouted(nodeId, selector, data);
        return result;
    }

    function isNodeAuthorized(bytes32 nodeId) external view override returns (bool) {
        return swarmRegistry[nodeId].isActive;
    }

    function setCallerStatus(address caller, bool status) external onlyCouncil {
        authorizedCallers[caller] = status;
    }

    function deactivateNode(bytes32 nodeId) external onlyCouncil {
        swarmRegistry[nodeId].isActive = false;
    }
}
