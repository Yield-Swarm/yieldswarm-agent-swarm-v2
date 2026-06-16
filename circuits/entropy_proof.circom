pragma circom 2.1.6;

// ZK¹ — Entropy proof circuit (D¹ boundaries + verifiable trust)
// Proves entropySeed = Poseidon(telemetry...) without revealing raw telemetry.

include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/comparators.circom";

/// @dev Hard range constraint — rejects malformed telemetry at circuit level (Task 3-4)
template BoundedInput(maxValue) {
    signal input in;
    component bound = LessThan(32);
    bound.in[0] <== in;
    bound.in[1] <== maxValue + 1;
    bound.out === 1;
}

/// @dev EntropyProof — public entropySeed, private telemetry vector
template EntropyProof() {
    // ---- Private signals (never revealed on-chain) ----
    signal input gpuTempScaled;       // 0..100  (celsius integer)
    signal input vramScaled;          // 0..100  (percent)
    signal input powerScaled;         // 0..600  (watts)
    signal input inferenceTpsScaled;  // 0..200  (tokens/sec integer)
    signal input packetLossScaled;    // 0..100  (percent x100 or bps/100)
    signal input tokenId;             // NFT tokenId salt
    signal input nonce;               // rolling window nonce
    signal input nodeProfile;         // 0=rtx5090, 1=h100, 2=other

    // ---- Public output ----
    signal output entropySeed;

    // D¹ — range checks (Tasks 3-4)
    component rcTemp = BoundedInput(100);
    rcTemp.in <== gpuTempScaled;

    component rcVram = BoundedInput(100);
    rcVram.in <== vramScaled;

    component rcPower = BoundedInput(600);
    rcPower.in <== powerScaled;

    component rcTps = BoundedInput(200);
    rcTps.in <== inferenceTpsScaled;

    component rcLoss = BoundedInput(100);
    rcLoss.in <== packetLossScaled;

    component rcProfile = BoundedInput(2);
    rcProfile.in <== nodeProfile;

    // ZK¹ — Poseidon hash binds private telemetry → public seed (Task 31)
    component hasher = Poseidon(8);
    hasher.inputs[0] <== gpuTempScaled;
    hasher.inputs[1] <== vramScaled;
    hasher.inputs[2] <== powerScaled;
    hasher.inputs[3] <== inferenceTpsScaled;
    hasher.inputs[4] <== packetLossScaled;
    hasher.inputs[5] <== tokenId;
    hasher.inputs[6] <== nonce;
    hasher.inputs[7] <== nodeProfile;

    entropySeed <== hasher.out;
}

// Public signal: entropySeed only
component main {public [entropySeed]} = EntropyProof();
