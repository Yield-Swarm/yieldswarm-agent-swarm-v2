/**
 * Resource exhaustion fallbacks — thermal, VRAM, network (Greek D¹).
 * @module src/automation/resource-guardrails
 */

import { MONITOR_LIMITS } from '../infrastructure/monitor-limits.js';

export const LIMITS = Object.freeze({
  THERMAL_C: MONITOR_LIMITS.THERMAL_C,
  VRAM_MAX_GB: MONITOR_LIMITS.VRAM_MAX_GB,
  VRAM_PCT: MONITOR_LIMITS.VRAM_MAX_PCT_RTX5090,
  NETWORK_DROP_PCT: MONITOR_LIMITS.NETWORK_DROP_PCT,
  MAX_CONCURRENT_INFERENCE: 8,
});

/**
 * @param {object} telemetry
 * @returns {{ ok: boolean, action: string, reason?: string }}
 */
export function evaluateGuardrails(telemetry) {
  if (telemetry.gpuTempC > LIMITS.THERMAL_C) {
    return { ok: false, action: 'throttle', reason: `thermal>${LIMITS.THERMAL_C}C` };
  }
  const vramGb = telemetry.vramUsedGb ?? ((telemetry.vramUsedPct ?? 0) / 100) * MONITOR_LIMITS.VRAM_TOTAL_GB_RTX5090;
  if (vramGb > LIMITS.VRAM_MAX_GB) {
    return { ok: false, action: 'evict_models', reason: `vram>${LIMITS.VRAM_MAX_GB}GB` };
  }
  if (telemetry.vramUsedPct > LIMITS.VRAM_PCT) {
    return { ok: false, action: 'evict_models', reason: `vram>${LIMITS.VRAM_PCT}%` };
  }
  if (telemetry.packetLossPct > LIMITS.NETWORK_DROP_PCT) {
    return { ok: false, action: 'failover_worker', reason: `packet_loss>${LIMITS.NETWORK_DROP_PCT}%` };
  }
  if ((telemetry.activeRequests ?? 0) > LIMITS.MAX_CONCURRENT_INFERENCE) {
    return { ok: false, action: 'queue', reason: 'concurrency_cap' };
  }
  return { ok: true, action: 'continue' };
}

export default { evaluateGuardrails, LIMITS };
