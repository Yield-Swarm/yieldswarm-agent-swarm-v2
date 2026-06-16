/**
 * TelemetryValidationBridge — pillar-scoped GPU telemetry → HardenedAuditEngine.
 * Used by Akash BERT worker integration and Mayhem Mode harnesses.
 */

import { HardenedAuditEngine } from "./entropy-core.js";
import { logPillarTelemetry } from "./pillar-telemetry-log.js";

/** P40 envelope + Mayhem sim ceiling */
export const DEFAULT_ENVELOPE = {
  maxVramGb: 28,
  maxTempC: 81,
  gpuModel: "nvidia-p40",
};

/**
 * @typedef {object} PulseResult
 * @property {string} pillarId
 * @property {string} status
 * @property {object} envelope
 * @property {object} sample
 * @property {object} auditBlock
 * @property {object} proofSeed
 * @property {object} chainVerify
 */

/**
 * @param {object} opts
 * @param {string} opts.pillarId
 * @param {number} opts.vramUsedGb
 * @param {number} opts.tempC
 * @param {number} [opts.utilizationPct]
 * @param {string} [opts.gpuId]
 * @param {object} [opts.envelope]
 * @returns {PulseResult}
 */
export function pulseGpuTelemetry(opts) {
  const pillarId = opts.pillarId || "04_akash_gpu_workers";
  const envelope = { ...DEFAULT_ENVELOPE, ...(opts.envelope || {}) };

  const sample = {
    vramUsedGb: Number(opts.vramUsedGb ?? 0),
    tempC: Number(opts.tempC ?? 0),
    utilizationPct: opts.utilizationPct !== undefined ? Number(opts.utilizationPct) : undefined,
    gpuId: opts.gpuId || envelope.gpuModel,
    timestamp: Date.now(),
  };

  let status = "green";
  if (sample.vramUsedGb > envelope.maxVramGb) status = "vram_pressure";
  if (sample.tempC > envelope.maxTempC) status = "thermal_pressure";
  if (sample.vramUsedGb > envelope.maxVramGb && sample.tempC > envelope.maxTempC) {
    status = "mayhem_breach";
  }

  const engine = new HardenedAuditEngine();
  const auditBlock = engine.ingest(sample);
  const proofSeed = engine.exportProofSeed();
  const chainVerify = engine.verifyChain();

  const result = {
    pillarId,
    status,
    envelope,
    sample,
    auditBlock: {
      index: auditBlock.index,
      blockVerificationHash: auditBlock.blockVerificationHash,
      sealedAt: auditBlock.sealedAt,
    },
    proofSeed,
    chainVerify,
    entropyQuality: engine.entropyQuality(),
  };

  logPillarTelemetry(pillarId, "gpu_telemetry_pulse", result);
  return result;
}

export default { pulseGpuTelemetry, DEFAULT_ENVELOPE };
