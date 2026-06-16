/**
 * RTX 5090 hardware telemetry — polls Ollama /api/ps on the Akash worker.
 */

import config from '../config.js';
import { requestJson } from '../lib/httpClient.js';

let latestTelemetry = {
  timestamp: null,
  live: false,
  source: 'rtx5090',
  models: [],
  vram_used: null,
  temperature: null,
  endpoint: config.inference.rtx5090Endpoint,
};

export function getLatestTelemetry() {
  return { ...latestTelemetry };
}

export async function refreshTelemetry() {
  const endpoint = config.inference.rtx5090Endpoint.replace(/\/$/, '');
  try {
    const data = await requestJson({
      method: 'GET',
      url: `${endpoint}/api/ps`,
      timeout: config.upstreamTimeoutMs,
    });
    latestTelemetry = {
      timestamp: Date.now(),
      live: true,
      source: 'rtx5090',
      models: data.models || [],
      vram_used: data.vram_used ?? data.memory ?? null,
      temperature: data.temperature ?? null,
      endpoint: config.inference.rtx5090Endpoint,
      raw: data,
    };
  } catch (err) {
    latestTelemetry = {
      ...latestTelemetry,
      timestamp: Date.now(),
      live: false,
      error: err.message || 'Failed to fetch 5090 telemetry',
    };
  }
  return getLatestTelemetry();
}

export async function ping() {
  try {
    await refreshTelemetry();
    return { live: latestTelemetry.live, source: 'rtx5090', endpoint: config.inference.rtx5090Endpoint };
  } catch (err) {
    return { live: false, source: 'rtx5090', error: err.message };
  }
}
