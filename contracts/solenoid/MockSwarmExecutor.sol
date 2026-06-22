// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockSwarmExecutor — test harness for Nexus routeCommand
contract MockSwarmExecutor {
    bytes public lastPayload;
    uint256 public lastValue;

    event Executed(bytes4 selector, bytes payload, uint256 value);

    function execute(bytes calldata data) external payable returns (bytes memory) {
        lastPayload = data;
        lastValue = msg.value;
        emit Executed(bytes4(keccak256("execute(bytes)")), data, msg.value);
        return abi.encode(true);
    }
}
