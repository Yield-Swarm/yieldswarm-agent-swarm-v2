const { SYSTEM_GUARDRAILS, TREASURY_SPLIT, validateTreasurySplit } = require("../../../lib/yieldswarm-config");

function healthHandler(req, res) {
  validateTreasurySplit(TREASURY_SPLIT);
  res.status(200).json({
    status: "ok",
    service: "great-delta-api",
    guardrailMs: SYSTEM_GUARDRAILS.maxOrchestrationLatencyMs,
    heartbeatSeconds: SYSTEM_GUARDRAILS.heartbeatIntervalSeconds,
    treasurySplit: TREASURY_SPLIT,
    timestamp: new Date().toISOString()
  });
}

module.exports = {
  healthHandler
};
