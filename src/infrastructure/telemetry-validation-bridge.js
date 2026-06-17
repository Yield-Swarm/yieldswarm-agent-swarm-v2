/**
 * TelemetryValidationBridge — pillar-scoped GPU telemetry → HardenedAuditEngine.
 * Used by Akash BERT worker integration and Mayhem Mode harnesses.
 */

import { createRequire } from 'node:module';
import { logPillarTelemetry } from './pillar-telemetry-log.js';

const require = createRequire(import.meta.url);
const { HardenedAuditEngine } = require('./entropy-core.js');

/** P40 envelope + Mayhem sim ceiling */
export const DEFAULT_ENVELOPE = {
  maxVramGb: 28,
  maxTempC: 81,
  gpuModel: 'nvidia-p40',
};

export function pulseGpuTelemetry(opts) {
  const pillarId = opts.pillarId || '04_akash_gpu_workers';
  const envelope = { ...DEFAULT_ENVELOPE, ...(opts.envelope || {}) };

  const sample = {
    vramUsedGb: Number(opts.vramUsedGb ?? 0),
    tempC: Number(opts.tempC ?? 0),
    utilizationPct: opts.utilizationPct !== undefined ? Number(opts.utilizationPct) : undefined,
    gpuId: opts.gpuId || envelope.gpuModel,
    timestamp: Date.now(),
  };

  let status = 'green';
  if (sample.vramUsedGb > envelope.maxVramGb) status = 'vram_pressure';
  if (sample.tempC > envelope.maxTempC) status = 'thermal_pressure';
  if (sample.vramUsedGb > envelope.maxVramGb && sample.tempC > envelope.maxTempC) {
    status = 'mayhem_breach';
  }

  const engine = new HardenedAuditEngine();
  const auditBlock = engine.registerExecutionBlock(
    { tenantHash: pillarId, payload: { pillarId, status } },
    {
      gpu_temperature: sample.tempC,
      vram_used_bytes: Math.round(sample.vramUsedGb * 1_000_000_000),
      tokens_per_sec: sample.utilizationPct ?? 0,
      timestamp: sample.timestamp,
    },
  );

  const result = {
    pillarId,
    status,
    envelope,
    sample,
    auditBlock: {
      blockVerificationHash: auditBlock.blockVerificationHash,
      entropyWindowDepth: auditBlock.entropyWindowDepth,
      integrityConfirmed: auditBlock.integrityConfirmed,
    },
    chainVerify: { valid: auditBlock.integrityConfirmed, errors: [] },
  };

  logPillarTelemetry(pillarId, 'gpu_telemetry_pulse', result);
  return result;
}

export default { pulseGpuTelemetry, DEFAULT_ENVELOPE };
