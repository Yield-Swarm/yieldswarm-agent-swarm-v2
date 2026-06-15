const { SYSTEM_GUARDRAILS } = require("./yieldswarm-config");

function enforceLatencyGuardrail(startEpochMs, nowEpochMs = Date.now()) {
  const elapsedMs = nowEpochMs - startEpochMs;
  const withinGuardrail = elapsedMs <= SYSTEM_GUARDRAILS.maxOrchestrationLatencyMs;
  return {
    elapsedMs,
    maxMs: SYSTEM_GUARDRAILS.maxOrchestrationLatencyMs,
    withinGuardrail
  };
}

module.exports = {
  enforceLatencyGuardrail
};
