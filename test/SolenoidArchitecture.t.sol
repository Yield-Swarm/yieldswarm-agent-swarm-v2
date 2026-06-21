// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Nexus} from "../contracts/solenoid/Nexus.sol";
import {Helix} from "../contracts/solenoid/Helix.sol";
import {Shadow} from "../contracts/solenoid/Shadow.sol";
import {MockSwarmExecutor} from "../contracts/solenoid/MockSwarmExecutor.sol";

contract SolenoidArchitectureTest is Test {
    Nexus nexus;
    Helix helix;
    Shadow shadow;
    MockSwarmExecutor executor;

    address council = address(uint160(uint256(keccak256("council"))));
    address vault = address(uint160(uint256(keccak256("vault"))));
    bytes32 nodeId = keccak256("agent-node-001");

    function setUp() public {
        nexus = new Nexus(council);
        executor = new MockSwarmExecutor();
        helix = new Helix(address(nexus), vault);
        shadow = new Shadow();

        vm.prank(council);
        nexus.registerNode(nodeId, address(executor), keccak256("yield-routing"), 10_000);

        vm.prank(council);
        nexus.setCallerStatus(address(helix), true);

        vm.prank(council);
        nexus.setCallerStatus(council, true);
    }

    function testNexusRoutesCommandToExecutor() public {
        bytes memory payload = abi.encodePacked(vault, uint256(1 ether), bytes("strategy"));

        vm.prank(council);
        bytes memory result = nexus.routeCommand(nodeId, MockSwarmExecutor.execute.selector, payload);

        assertGt(result.length, 0);
        assertEq(executor.lastPayload(), payload);
    }

    function testHelixDeploysThroughNexus() public {
        bytes32 poolId = keccak256("pool-iotex");
        bytes memory strategy = bytes("route-to-mining-root");

        helix.deployStrategicCapital(
            nodeId,
            poolId,
            1 ether,
            MockSwarmExecutor.execute.selector,
            strategy
        );

        assertEq(helix.poolAllocations(poolId), 1 ether);
        assertEq(helix.totalActiveResonancePools(), 1);
    }

    function testShadowCommitReveal() public {
        bytes memory payload = bytes("blinded-yield-intent");
        bytes32 salt = keccak256("salt");
        bytes32 stateHash = keccak256(abi.encodePacked(salt, payload, address(this)));

        shadow.submitBlindedIntent(stateHash, 1);

        vm.warp(block.timestamp + 2);
        bool ok = shadow.revealAndSettleIntent(stateHash, salt, payload);
        assertTrue(ok);
        assertFalse(shadow.isCommitted(stateHash));
    }

    function testShadowRevertsOnBadProof() public {
        bytes32 stateHash = keccak256("wrong-hash");
        shadow.submitBlindedIntent(stateHash, 0);
        vm.warp(block.timestamp + 1);

        vm.expectRevert(Shadow.ProofMismatch.selector);
        shadow.revealAndSettleIntent(stateHash, bytes32(uint256(1)), bytes("x"));
    }
}
