pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";

// Max scaled input (2 decimal precision on 0-100.00 range)
template InputBounds() {
    signal input value;
    signal output ok;

    component lo = GreaterEqThan(16);
    lo.in[0] <== value;
    lo.in[1] <== 0;

    component hi = LessEqThan(16);
    hi.in[0] <== value;
    hi.in[1] <== 10000;

    ok <== lo.out * hi.out;
}

template ReputationScore() {
    // Private battle metrics (never revealed on-chain)
    signal input winRate;
    signal input consistency;
    signal input peerReview;
    signal input stakeWeight;

    // Public auditable weights (sum should equal 10000 for canonical formula)
    signal input weights[4];

    // Public score output (0-10000 => 0.00-100.00 display scale)
    signal output score;

    component b0 = InputBounds();
    b0.value <== winRate;
    component b1 = InputBounds();
    b1.value <== consistency;
    component b2 = InputBounds();
    b2.value <== peerReview;
    component b3 = InputBounds();
    b3.value <== stakeWeight;

    b0.ok === 1;
    b1.ok === 1;
    b2.ok === 1;
    b3.ok === 1;

    signal weightedSum;
    weightedSum <== winRate * weights[0]
        + consistency * weights[1]
        + peerReview * weights[2]
        + stakeWeight * weights[3];

    signal totalWeight;
    totalWeight <== weights[0] + weights[1] + weights[2] + weights[3];

    // score = weightedSum / totalWeight (0–10000 display scale)
    score * totalWeight === weightedSum;
}

component main { public [weights] } = ReputationScore();
