pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

/// @title EntropyProof
/// @notice Paradigm Shift ($PDs^1$) — prove hardware telemetry seed is within bounds
///         without revealing raw vram/temp metrics on-chain.
///
/// Public inputs:
///   - commitment: Poseidon hash of (vramScaled, tempScaled, nonce)
///   - vramMaxScaled, tempMaxScaled: policy ceilings (scaled by 1000)
///
/// Private inputs:
///   - vramScaled, tempScaled: actual readings * 1000 (fixed-point)
///   - nonce: domain separator
template EntropyProof() {
    signal input commitment;
    signal input vramMaxScaled;
    signal input tempMaxScaled;

    signal input vramScaled;
    signal input tempScaled;
    signal input nonce;

    // Range checks: 0 <= reading <= max
    component vramCheck = LessEqThan(32);
    vramCheck.in[0] <== vramScaled;
    vramCheck.in[1] <== vramMaxScaled;
    vramCheck.out === 1;

    component tempCheck = LessEqThan(32);
    tempCheck.in[0] <== tempScaled;
    tempCheck.in[1] <== tempMaxScaled;
    tempCheck.out === 1;

    // commitment = Poseidon(vramScaled, tempScaled, nonce)
    component hasher = Poseidon(3);
    hasher.inputs[0] <== vramScaled;
    hasher.inputs[1] <== tempScaled;
    hasher.inputs[2] <== nonce;

    commitment === hasher.out;
}

component main { public [commitment, vramMaxScaled, tempMaxScaled] } = EntropyProof();
