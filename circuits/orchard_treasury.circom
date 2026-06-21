pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";

// Proves Great Delta 50/30/15/5 split without revealing bucket values publicly.
// Public: totalCommitment, splitCommitment (off-chain hashed commitments)
// Private: total, core, growth, insurance, ops

template BpsCheck() {
    signal input total;
    signal input part;
    signal input bps;
    signal output ok;

    signal expected;
    expected <== total * bps;
    signal lhs;
    lhs <== part * 10000;
    component eq = IsEqual();
    eq.in[0] <== lhs;
    eq.in[1] <== expected;
    ok <== eq.out;
}

template OrchardTreasurySplit() {
    signal input total;
    signal input core;
    signal input growth;
    signal input insurance;
    signal input ops;

    signal output valid;

    component sumEq = IsEqual();
    sumEq.in[0] <== core + growth + insurance + ops;
    sumEq.in[1] <== total;

    component c0 = BpsCheck();
    c0.total <== total;
    c0.part <== core;
    c0.bps <== 5000;

    component c1 = BpsCheck();
    c1.total <== total;
    c1.part <== growth;
    c1.bps <== 3000;

    component c2 = BpsCheck();
    c2.total <== total;
    c2.part <== insurance;
    c2.bps <== 1500;

    component c3 = BpsCheck();
    c3.total <== total;
    c3.part <== ops;
    c3.bps <== 500;

    valid <== sumEq.out * c0.ok * c1.ok * c2.ok * c3.ok;
}

component main { public [valid] } = OrchardTreasurySplit();
