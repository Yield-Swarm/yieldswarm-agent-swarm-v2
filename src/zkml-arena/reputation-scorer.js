/**
 * Deterministic reputation scoring — mirrors circuits/reputation_score.circom.
 * All inputs scaled 0–10000 (2 decimal fixed-point on 0–100).
 */

const DEFAULT_WEIGHTS = [4000, 3000, 2000, 1000];
const MAX_INPUT = 10_000;

function assertBounded(name, value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > MAX_INPUT) {
    throw new Error(`${name} must be an integer 0–${MAX_INPUT}, got ${value}`);
  }
  return Math.floor(n);
}

/**
 * @param {{ winRate: number, consistency: number, peerReview: number, stakeWeight: number }} inputs
 * @param {number[]} [weights]
 * @returns {number} score 0–10000
 */
function computeReputationScore(inputs, weights = DEFAULT_WEIGHTS) {
  const winRate = assertBounded("winRate", inputs.winRate);
  const consistency = assertBounded("consistency", inputs.consistency);
  const peerReview = assertBounded("peerReview", inputs.peerReview);
  const stakeWeight = assertBounded("stakeWeight", inputs.stakeWeight);

  if (weights.length !== 4) {
    throw new Error("weights must have length 4");
  }

  const totalWeight = weights.reduce((a, w) => a + Number(w), 0);
  if (totalWeight <= 0) {
    throw new Error("totalWeight must be positive");
  }

  const weightedSum =
    winRate * weights[0] +
    consistency * weights[1] +
    peerReview * weights[2] +
    stakeWeight * weights[3];

  return Math.floor(weightedSum / totalWeight);
}

/**
 * @param {object} payload
 * @returns {string} 0x-prefixed keccak256 hex
 */
function hashBattleCommitment(payload) {
  const crypto = require("crypto");
  const canonical = JSON.stringify(payload, Object.keys(payload).sort());
  return (
    "0x" +
    crypto.createHash("sha256").update(canonical).digest("hex")
  );
}

module.exports = {
  DEFAULT_WEIGHTS,
  MAX_INPUT,
  computeReputationScore,
  hashBattleCommitment,
};
