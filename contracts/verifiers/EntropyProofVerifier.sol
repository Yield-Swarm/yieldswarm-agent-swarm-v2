// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEntropyProofVerifier} from "../interfaces/IEntropyProofVerifier.sol";

/// @title DevEntropyProofVerifier
/// @notice Testnet/dev verifier — trusted prover submits pre-image commitment (NOT production ZK).
/// @dev Replace with EntropyProofVerifier.generated.sol from `circuits npm run verify-key` on mainnet.
contract DevEntropyProofVerifier is IEntropyProofVerifier {
    address public owner;
    address public trustedProver;
    mapping(bytes32 => bool) public approvedCommitments;

    error NotOwner();
    error NotTrustedProver();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyTrustedProver() {
        if (msg.sender != trustedProver) revert NotTrustedProver();
        _;
    }

    constructor(address initialOwner, address prover) {
        owner = initialOwner;
        trustedProver = prover;
    }

    function setTrustedProver(address prover) external onlyOwner {
        trustedProver = prover;
    }

    function approveCommitment(bytes32 commitment) external onlyTrustedProver {
        approvedCommitments[commitment] = true;
    }

    function circuitVersion() external pure returns (string memory) {
        return "1.0.0-dev";
    }

    /// @inheritdoc IEntropyProofVerifier
    function verifyEntropyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[1] calldata pubSignals
    ) external view returns (bool) {
        if (pubSignals[0] == 0) revert InvalidPublicSignal();
        bytes32 commitment = bytes32(pubSignals[0]);
        return approvedCommitments[commitment];
    }
}

/// @title EntropyProofVerifier
/// @notice Production wrapper — link generated Groth16 verifier from snarkjs export.
/// @dev Run: cd circuits && npm run full-build && npm run verify-key
contract EntropyProofVerifier is IEntropyProofVerifier {
    address public immutable generatedVerifier;
    string public constant CIRCUIT_VERSION = "1.0.0";

    constructor(address _generatedVerifier) {
        if (_generatedVerifier == address(0)) revert VerifierNotConfigured();
        generatedVerifier = _generatedVerifier;
    }

    function circuitVersion() external pure returns (string memory) {
        return CIRCUIT_VERSION;
    }

    function verifyEntropyProof(
        uint256[2] calldata pi_a,
        uint256[2][2] calldata pi_b,
        uint256[2] calldata pi_c,
        uint256[1] calldata pubSignals
    ) external view returns (bool) {
        if (generatedVerifier == address(0)) revert VerifierNotConfigured();
        if (pubSignals[0] == 0) revert InvalidPublicSignal();

        (bool ok, bytes memory ret) = generatedVerifier.staticcall(
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[1])",
                pi_a, pi_b, pi_c, pubSignals
            )
        );
        if (!ok || ret.length == 0) revert InvalidProof();
        return abi.decode(ret, (bool));
    }
}
