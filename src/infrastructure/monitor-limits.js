/**
 * Shared monitor limits — D¹ Mayhem Mode hard caps (RTX 5090).
 * @module src/infrastructure/monitor-limits
 */

export const MONITOR_LIMITS = Object.freeze({
  THERMAL_C: 83,
  VRAM_MAX_GB: 29.5,
  VRAM_TOTAL_GB_RTX5090: 32,
  VRAM_TOTAL_GB_H100: 80,
  NETWORK_DROP_PCT: 5,
  get VRAM_MAX_PCT_RTX5090() {
    return (this.VRAM_MAX_GB / this.VRAM_TOTAL_GB_RTX5090) * 100;
  },
});

/**
 * @param {object} telemetry
 * @param {'rtx5090'|'h100'} [profile]
 */
export function evaluateHardwareLimits(telemetry, profile = 'rtx5090') {
  const totalGb = profile === 'h100' ? MONITOR_LIMITS.VRAM_TOTAL_GB_H100 : MONITOR_LIMITS.VRAM_TOTAL_GB_RTX5090;
  const maxGb = profile === 'h100' ? totalGb * 0.92 : MONITOR_LIMITS.VRAM_MAX_GB;
  const vramGb = telemetry.vramUsedGb ?? (telemetry.vramUsedPct / 100) * totalGb;

  if (telemetry.gpuTempC > MONITOR_LIMITS.THERMAL_C) {
    return { ok: false, action: 'thermal_shutdown', reason: `temp>${MONITOR_LIMITS.THERMAL_C}C` };
  }
  if (vramGb > maxGb) {
    return { ok: false, action: 'vram_evict', reason: `vram>${maxGb}GB` };
  }
  if ((telemetry.packetLossPct ?? 0) > MONITOR_LIMITS.NETWORK_DROP_PCT) {
    return { ok: false, action: 'network_failover', reason: 'packet_loss' };
  }
  return { ok: true, action: 'continue', vramGb, maxGb };
}

export default { MONITOR_LIMITS, evaluateHardwareLimits };
