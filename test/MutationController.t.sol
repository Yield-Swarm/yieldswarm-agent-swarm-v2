// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldSwarmNFT} from "../contracts/YieldSwarmNFT.sol";
import {MutationController} from "../contracts/MutationController.sol";
import {EntropyProofVerifier} from "../contracts/verifiers/EntropyProofVerifier.sol";

contract MutationControllerTest is Test {
    YieldSwarmNFT internal nft;
    EntropyProofVerifier internal verifier;
    MutationController internal controller;

    address internal admin = address(0xA11CE);
    address internal relayer = address(0xBEEF);

  function setUp() public {
    nft = new YieldSwarmNFT(admin);
    verifier = new EntropyProofVerifier(admin);
    controller = new MutationController(address(nft), address(verifier), admin);

    vm.startPrank(admin);
    nft.setMutationController(address(controller));
    controller.grantRole(controller.RELAYER_ROLE(), relayer);
    controller.grantRole(controller.AUTOMATION_ROLE(), relayer);
    vm.stopPrank();

    vm.prank(admin);
    nft.mintAgent(admin, 2, "ipfs://genesis");
  }

  function testWeeklyMutationTrigger() public {
    vm.warp(8 days);
    vm.prank(relayer);
    controller.triggerWeeklyMutation();
    assertEq(controller.lastMutationWeek(), block.timestamp / 1 weeks);
  }

  function testAttestedMutation() public {
    uint256 commitment = 12345;
    bytes32 blockHash = keccak256("entropy-block");

    vm.prank(relayer);
    controller.executeAgentMutationWithAttestation(
      0,
      3,
      "ipfs://mutated",
      commitment,
      blockHash,
      8000
    );

    assertTrue(controller.consumedCommitments(commitment));
    assertEq(nft.getAgentTier(0), 3);
    assertEq(nft.tokenURI(0), "ipfs://mutated");
  }

  function testRejectsLowEntropyQuality() public {
    vm.prank(relayer);
    vm.expectRevert();
    controller.executeAgentMutationWithAttestation(0, 3, "ipfs://x", 99, bytes32(uint256(1)), 1000);
  }
}
