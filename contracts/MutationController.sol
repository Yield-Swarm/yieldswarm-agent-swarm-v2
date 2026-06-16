// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEntropyVerifier} from "./interfaces/IEntropyVerifier.sol";
import {YieldSwarmNFT} from "./YieldSwarmNFT.sol";

/// @title MutationController
/// @notice Verifies ZK entropy proofs before triggering NFT mutation.
contract MutationController {
    YieldSwarmNFT public immutable nft;
    IEntropyVerifier public entropyVerifier;

    uint256 public constant MIN_QUALITY = 85;
    uint256 public constant MAX_QUALITY = 100;

    address public owner;

    event EntropyProofSubmitted(
        uint256 indexed tokenId,
        bytes32 seed,
        uint256 commitment,
        uint256 quality,
        address indexed submitter
    );
    event EntropyVerifierUpdated(address indexed previous, address indexed next);
    event OwnerTransferred(address indexed previous, address indexed next);

    error NotOwner();
    error InvalidQuality(uint256 quality);
    error InvalidZkProof();
    error TokenDoesNotExist(uint256 tokenId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address nft_, address entropyVerifier_) {
        nft = YieldSwarmNFT(nft_);
        entropyVerifier = IEntropyVerifier(entropyVerifier_);
        owner = msg.sender;
    }

    function setEntropyVerifier(address verifier) external onlyOwner {
        address previous = address(entropyVerifier);
        entropyVerifier = IEntropyVerifier(verifier);
        emit EntropyVerifierUpdated(previous, verifier);
    }

    function transferOwnership(address next) external onlyOwner {
        owner = next;
        emit OwnerTransferred(msg.sender, next);
    }

  /// @param pubSignals [commitment, quality] from the entropy circuit public outputs.
    function submitEntropyProof(
        uint256 tokenId,
        bytes32 seed,
        uint256[2] calldata pubSignals,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external {
        _assertTokenExists(tokenId);

        uint256 commitment = pubSignals[0];
        uint256 quality = pubSignals[1];
        if (quality < MIN_QUALITY || quality > MAX_QUALITY) {
            revert InvalidQuality(quality);
        }

        bool valid = entropyVerifier.verifyProof(proofA, proofB, proofC, pubSignals);
        if (!valid) revert InvalidZkProof();

        nft.mutate(tokenId, seed, commitment, quality);
        emit EntropyProofSubmitted(tokenId, seed, commitment, quality, msg.sender);
    }

    function verifyEntropyProof(
        uint256[2] calldata pubSignals,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external view returns (bool) {
        return entropyVerifier.verifyProof(proofA, proofB, proofC, pubSignals);
    }

    function _assertTokenExists(uint256 tokenId) internal view {
        try nft.ownerOf(tokenId) returns (address) {
            return;
        } catch {
            revert TokenDoesNotExist(tokenId);
        }
    }
}
