/**
 * Resource exhaustion fallbacks — thermal, VRAM, network (Greek D¹).
 * @module src/automation/resource-guardrails
 */

export const LIMITS = Object.freeze({
  THERMAL_C: 85,
  VRAM_PCT: 92,
  NETWORK_DROP_PCT: 5,
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
