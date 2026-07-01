/**
 * ZKML Arena reputation engine — extends EntropyCore for backward compatibility.
 */

const { EntropyCore } = require("../infrastructure/entropy-core");
const {
  DEFAULT_WEIGHTS,
  computeReputationScore,
  hashBattleCommitment,
} = require("./reputation-scorer");
const { callQuarantinedJudge } = require("./quarantine-judge");
const {
  proveReputation,
  verifyReputationProof,
} = require("./zk-reputation-prover");

const SBT_THRESHOLD = 7000; // 70.00 display score

class ZKMLReputationEngine extends EntropyCore {
  constructor(options = {}) {
    super(options);
    this.weights = options.weights ?? DEFAULT_WEIGHTS;
    this.sbtThreshold = options.sbtThreshold ?? SBT_THRESHOLD;
  }

  async callQuarantinedJudge(battle) {
    return callQuarantinedJudge(battle);
  }

  /**
   * @param {{ winRate: number, consistency: number, stakeWeight: number, battleLog?: string, rounds?: number }} privateInputs
   * @param {string} agentDid
   * @param {{ battleId?: string }} [meta]
   */
  async computeAndProve(privateInputs, agentDid, meta = {}) {
    const peerReview = await this.callQuarantinedJudge({
      ...privateInputs,
      winRate: privateInputs.winRate,
      consistency: privateInputs.consistency,
    });

    const metrics = {
      winRate: privateInputs.winRate,
      consistency: privateInputs.consistency,
      peerReview,
      stakeWeight: privateInputs.stakeWeight,
    };

    const score = computeReputationScore(metrics, this.weights);
    const inputHash = hashBattleCommitment({
      ...metrics,
      agentDid,
      battleId: meta.battleId ?? null,
      weights: this.weights,
    });

    const proofBundle = await proveReputation({
      ...metrics,
      weights: this.weights,
      score,
    });

    const proofValid = await verifyReputationProof(proofBundle);

    return {
      score,
      proof: proofBundle.proof,
      publicSignals: proofBundle.publicSignals,
      proofValid,
      mockProof: proofBundle.mockProof ?? false,
      inputHash,
      proofHash: inputHash,
      agentDid,
      peerReview,
      weights: this.weights,
      sbtUpdated: proofValid && score >= this.sbtThreshold,
      timestamp: Date.now(),
    };
  }

  async verifyProof(proofBundle) {
    return verifyReputationProof(proofBundle);
  }
}

module.exports = {
  ZKMLReputationEngine,
  SBT_THRESHOLD,
};
