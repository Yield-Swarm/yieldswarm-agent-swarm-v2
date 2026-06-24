/**
 * Starlink API adapter (pillar 7 DePIN extension) — stub until STARLINK_API_KEY is set.
 * @see config/neural_mesh/external_apis.yaml
 */

const STARLINK_BASE = process.env.STARLINK_API_BASE || 'https://api.starlink.com';

export function getStarlinkStatus() {
  const configured = Boolean(process.env.STARLINK_API_KEY);
  return {
    configured,
    baseUrl: STARLINK_BASE,
    pillar: 7,
    role: 'backhaul_mesh',
    note: configured
      ? 'Ready for terminal status polling — implement fetch in starlinkFetch()'
      : 'Set STARLINK_API_KEY in Vault or deploy/env',
  };
}

/**
 * @param {string} terminalId
 */
export async function starlinkFetchTerminal(terminalId) {
  if (!process.env.STARLINK_API_KEY) {
    return {
      ok: false,
      terminalId,
      simulated: true,
      downlink_mbps: 0,
      uplink_mbps: 0,
      latency_ms: null,
      note: 'STARLINK_API_KEY not configured',
    };
  }

  // Placeholder for live Starlink Enterprise API when credentials are available
  return {
    ok: true,
    terminalId,
    downlink_mbps: null,
    uplink_mbps: null,
    latency_ms: null,
    note: 'Wire official Starlink API client when enterprise endpoint is confirmed',
  };
}
