const { enforceLatencyGuardrail } = require("../../../lib/latency-guardrail");

function telemetryHandler(req, res) {
  const requestStartMs = Number(req.headers["x-request-start-ms"] || Date.now());
  const guardrail = enforceLatencyGuardrail(requestStartMs);

  res.status(200).json({
    stream: "great-delta",
    guardrail,
    metrics: {
      event: req.body?.event || "heartbeat",
      source: req.body?.source || "unknown",
      p95TargetMs: 80
    },
    timestamp: new Date().toISOString()
  });
}

module.exports = {
  telemetryHandler
};
