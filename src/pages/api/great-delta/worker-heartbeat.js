const crypto = require("crypto");
const { SYSTEM_GUARDRAILS } = require("../../../lib/yieldswarm-config");

function workerHeartbeatHandler(req, res) {
  const agentId = req.body?.agentId || "unknown-agent";
  const sentAt = req.body?.sentAt || new Date().toISOString();
  const payload = `${agentId}:${sentAt}`;
  const signature = crypto.createHash("sha256").update(payload).digest("hex");

  res.status(202).json({
    accepted: true,
    agentId,
    sentAt,
    heartbeatIntervalSeconds: SYSTEM_GUARDRAILS.heartbeatIntervalSeconds,
    signature,
    note: "Replace local hash with HMAC/KMS signing in production."
  });
}

module.exports = {
  workerHeartbeatHandler
};
