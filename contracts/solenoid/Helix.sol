// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INexus} from "../interfaces/INexus.sol";
import {IHelix} from "../interfaces/IHelix.sol";

/// @title Helix — Solenoid Layer 2: yield optimization matrix
/// @dev Routes authenticated capital deployment through Nexus swarm nodes.
contract Helix is IHelix {
    INexus public immutable nexusCore;
    address public immutable assetVault;

    uint256 public totalActiveResonancePools;
    mapping(bytes32 => uint256) public poolAllocations;

    error NexusAuthFailed();

    constructor(address _nexusCore, address _assetVault) {
        nexusCore = INexus(_nexusCore);
        assetVault = _assetVault;
    }

    function deployStrategicCapital(
        bytes32 nodeId,
        bytes32 poolId,
        uint256 amount,
        bytes4 executionSelector,
        bytes calldata executionPayload
    ) external override {
        if (!nexusCore.isNodeAuthorized(nodeId)) revert NexusAuthFailed();

        poolAllocations[poolId] += amount;
        totalActiveResonancePools += 1;

        nexusCore.routeCommand(
            nodeId,
            executionSelector,
            abi.encodePacked(assetVault, amount, executionPayload)
        );

        emit StrategyExecuted(poolId, amount);
    }
}
