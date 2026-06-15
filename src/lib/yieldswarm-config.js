const TREASURY_SPLIT = Object.freeze({
  vault: 50,
  operations: 30,
  ecosystem: 15,
  sovereignReserve: 5
});

const SYSTEM_GUARDRAILS = Object.freeze({
  maxOrchestrationLatencyMs: 80,
  heartbeatIntervalSeconds: 420
});

function validateTreasurySplit(split = TREASURY_SPLIT) {
  const values = Object.values(split);
  const total = values.reduce((sum, value) => sum + value, 0);
  if (total !== 100) {
    throw new Error(`Invalid treasury split total=${total}, expected=100`);
  }
  return true;
}

module.exports = {
  TREASURY_SPLIT,
  SYSTEM_GUARDRAILS,
  validateTreasurySplit
};
