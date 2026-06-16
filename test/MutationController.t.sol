// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MutationController} from "../contracts/MutationController.sol";
import {YieldSwarmNFT} from "../contracts/YieldSwarmNFT.sol";
import {MockEntropyVerifier} from "../contracts/MockEntropyVerifier.sol";

contract MutationControllerTest is Test {
    MutationController controller;
    YieldSwarmNFT nft;
    MockEntropyVerifier verifier;

    address user = address(0xBEEF);

    function setUp() public {
        verifier = new MockEntropyVerifier();
        nft = new YieldSwarmNFT("YieldSwarm", "YSW");
        controller = new MutationController(address(nft), address(verifier));
        nft.setMutationController(address(controller));
    }

    function testSubmitEntropyProofMutatesNft() public {
        uint256 tokenId = nft.mint(user);

        uint256[2] memory pubSignals = [uint256(0xabc123), uint256(92)];
        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(user);
        controller.submitEntropyProof(
            tokenId,
            bytes32(uint256(0xDEAD)),
            pubSignals,
            proofA,
            proofB,
            proofC
        );

        (
            bytes32 seed,
            uint256 commitment,
            uint256 quality,
        ) = nft.mutations(tokenId);

        assertEq(seed, bytes32(uint256(0xDEAD)));
        assertEq(commitment, pubSignals[0]);
        assertEq(quality, 92);
    }

    function testRevertsOnLowQuality() public {
        uint256 tokenId = nft.mint(user);
        uint256[2] memory pubSignals = [uint256(1), uint256(50)];

        vm.expectRevert(abi.encodeWithSelector(MutationController.InvalidQuality.selector, 50));
        controller.submitEntropyProof(
            tokenId,
            bytes32(uint256(1)),
            pubSignals,
            [uint256(0), uint256(0)],
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            [uint256(0), uint256(0)]
        );
    }
}
