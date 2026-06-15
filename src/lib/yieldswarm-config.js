/**
 * Canonical Great Delta 50/30/15/5 treasury split + legacy quadrant-IV aliases.
 */

const GREAT_DELTA_SPLIT_BPS = Object.freeze({
  coreTreasury: 5000,
  growthTreasury: 3000,
  insuranceTreasury: 1500,
  opsTreasury: 500,
});

/** Legacy quadrant-IV labels (same ratios as canonical buckets). */
const LEGACY_TREASURY_SPLIT = Object.freeze({
  vault: 50,
  operations: 30,
  ecosystem: 15,
  sovereignReserve: 5,
});

/** @deprecated Use LEGACY_TREASURY_SPLIT — kept for existing DePIN worker handlers. */
const TREASURY_SPLIT = LEGACY_TREASURY_SPLIT;

const SYSTEM_GUARDRAILS = Object.freeze({
  maxOrchestrationLatencyMs: 80,
  heartbeatIntervalSeconds: 420,
});

function validateTreasurySplit(split = LEGACY_TREASURY_SPLIT) {
  const values = Object.values(split);
  const total = values.reduce((sum, value) => sum + value, 0);
  if (total !== 100) {
    throw new Error(`Invalid treasury split total=${total}, expected=100`);
  }
  return true;
}

function validateGreatDeltaBps(bps = GREAT_DELTA_SPLIT_BPS) {
  const total = Object.values(bps).reduce((sum, value) => sum + value, 0);
  if (total !== 10_000) {
    throw new Error(`Invalid Great Delta BPS total=${total}, expected=10000`);
  }
  return true;
}

module.exports = {
  GREAT_DELTA_SPLIT_BPS,
  LEGACY_TREASURY_SPLIT,
  TREASURY_SPLIT,
  SYSTEM_GUARDRAILS,
  validateTreasurySplit,
  validateGreatDeltaBps,
};
