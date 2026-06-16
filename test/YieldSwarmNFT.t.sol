// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {YieldSwarmNFT} from "../contracts/YieldSwarmNFT.sol";

contract YieldSwarmNFTTest is Test {
    YieldSwarmNFT internal nft;
    address internal owner = address(0xA11CE);
    address internal oracle = address(0xB0B);
    uint256 internal oraclePk = 0xBEEF;

    function setUp() public {
        nft = new YieldSwarmNFT(owner);
        oracle = vm.addr(oraclePk);
        vm.prank(owner);
        nft.setOracleAuthorized(oracle, true);
    }

    function testMintAgent() public {
        vm.prank(owner);
        uint256 id = nft.mintAgent(owner, 3, "ipfs://genesis");
        assertEq(id, 0);
        assertEq(nft.getAgentTier(id), 3);
        assertEq(nft.tokenURI(id), "ipfs://genesis");
    }

    function testOracleUpdatesUri() public {
        vm.prank(owner);
        uint256 id = nft.mintAgent(owner, 2, "ipfs://v0");

        bytes32 digest = keccak256("callback-1");
        bytes32 payload = keccak256(abi.encode(id, "ipfs://v1", digest, block.chainid));
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(payload);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePk, ethSigned);

        vm.prank(oracle);
        nft.oracleUpdateUri(id, "ipfs://v1", digest, abi.encodePacked(r, s, v));

        assertEq(nft.tokenURI(id), "ipfs://v1");
    }
}
