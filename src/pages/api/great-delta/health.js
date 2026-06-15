const { SYSTEM_GUARDRAILS, LEGACY_TREASURY_SPLIT, GREAT_DELTA_SPLIT_BPS, validateTreasurySplit, validateGreatDeltaBps } = require("../../../lib/yieldswarm-config");

function healthHandler(req, res) {
  validateTreasurySplit(LEGACY_TREASURY_SPLIT);
  validateGreatDeltaBps(GREAT_DELTA_SPLIT_BPS);
  res.status(200).json({
    status: "ok",
    service: "great-delta-api",
    guardrailMs: SYSTEM_GUARDRAILS.maxOrchestrationLatencyMs,
    heartbeatSeconds: SYSTEM_GUARDRAILS.heartbeatIntervalSeconds,
    policy: "50/30/15/5",
    splitBps: GREAT_DELTA_SPLIT_BPS,
    treasurySplit: LEGACY_TREASURY_SPLIT,
    timestamp: new Date().toISOString()
  });
}

module.exports = {
  healthHandler
};
