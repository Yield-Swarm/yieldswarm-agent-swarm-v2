pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

// Bounds mirror src/infrastructure/entropy-bounds.js
template SampleBounds() {
    signal input t;
    signal input p;
    signal input s;
    signal input e;
    signal output inBounds;

    component tLo = GreaterEqThan(16);
    tLo.in[0] <== t;
    tLo.in[1] <== 3000;
    component tHi = LessEqThan(16);
    tHi.in[0] <== t;
    tHi.in[1] <== 9500;

    component pLo = GreaterEqThan(16);
    pLo.in[0] <== p;
    pLo.in[1] <== 50;
    component pHi = LessEqThan(16);
    pHi.in[0] <== p;
    pHi.in[1] <== 800;

    component sLo = GreaterEqThan(16);
    sLo.in[0] <== s;
    sLo.in[1] <== 0;
    component sHi = LessEqThan(16);
    sHi.in[0] <== s;
    sHi.in[1] <== 100000;

    component eLo = GreaterEqThan(16);
    eLo.in[0] <== e;
    eLo.in[1] <== 0;
    component eHi = LessEqThan(16);
    eHi.in[0] <== e;
    eHi.in[1] <== 1000;

    signal tOk;
    signal pOk;
    signal sOk;
    signal eOk;
    tOk <== tLo.out * tHi.out;
    pOk <== pLo.out * pHi.out;
    sOk <== sLo.out * sHi.out;
    eOk <== eLo.out * eHi.out;
    inBounds <== tOk * pOk * sOk * eOk;
}

template PoseidonSample() {
    signal input telemetry[5];
    signal output hash;

    component p = Poseidon(5);
    for (var i = 0; i < 5; i++) {
        p.inputs[i] <== telemetry[i];
    }
    hash <== p.out;
}

template Sum128() {
    signal input in[128];
    signal output out;

    signal sums[129];
    sums[0] <== 0;
    for (var i = 0; i < 128; i++) {
        sums[i + 1] <== sums[i] + in[i];
    }
    out <== sums[128];
}

template EntropyProof() {
    signal input telemetry[128][5];
    signal input quality;
    signal output outCommitment;
    signal output outQuality;

    component boundCheck[128];
    component samples[128];
    signal sampleHashes[128];
    signal inBoundsFlags[128];
    signal rolling[129];

    rolling[0] <== 0;

    for (var i = 0; i < 128; i++) {
        boundCheck[i] = SampleBounds();
        boundCheck[i].t <== telemetry[i][0];
        boundCheck[i].p <== telemetry[i][1];
        boundCheck[i].s <== telemetry[i][2];
        boundCheck[i].e <== telemetry[i][3];
        inBoundsFlags[i] <== boundCheck[i].inBounds;

        samples[i] = PoseidonSample();
        for (var j = 0; j < 5; j++) {
            samples[i].telemetry[j] <== telemetry[i][j];
        }
        sampleHashes[i] <== samples[i].hash;

        component fold = Poseidon(2);
        fold.inputs[0] <== rolling[i];
        fold.inputs[1] <== sampleHashes[i];
        rolling[i + 1] <== fold.out;
    }

    component counter = Sum128();
    for (var k = 0; k < 128; k++) {
        counter.in[k] <== inBoundsFlags[k];
    }

    outCommitment <== rolling[128];
    outQuality <== 85 + (counter.out * 15) \ 128;
    quality === outQuality;
}

component main { public [outCommitment, outQuality] } = EntropyProof();
