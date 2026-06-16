// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEntropyVerifier} from "./interfaces/IEntropyVerifier.sol";

/// @notice Testnet / dev verifier — checks quality bounds only.
///         Replace with snarkjs-generated Groth16Verifier on Sepolia.
contract MockEntropyVerifier is IEntropyVerifier {
    uint256 public constant MIN_QUALITY = 85;
    uint256 public constant MAX_QUALITY = 100;

    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[2] calldata pubSignals
    ) external pure returns (bool) {
        uint256 quality = pubSignals[1];
        return quality >= MIN_QUALITY && quality <= MAX_QUALITY;
    }
}
