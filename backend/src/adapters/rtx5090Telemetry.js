/**
 * RTX 5090 hardware telemetry — Ollama /api/ps or vLLM /v1/models + /metrics.
 */

import config from '../config.js';
import { requestJson } from '../lib/httpClient.js';

function primaryUrl() {
  return (
    config.inference.rtx5090VllmBaseUrl ||
    config.inference.rtx5090Endpoint
  ).replace(/\/$/, '');
}

function isVllm(url) {
  const mode = config.inference.rtx5090ApiMode;
  if (mode === 'vllm') return true;
  if (mode === 'ollama') return false;
  return url.includes(':8000');
}

let latestTelemetry = {
  timestamp: null,
  live: false,
  source: 'rtx5090',
  backend: 'unknown',
  models: [],
  vram_used: null,
  tokensPerSecond: null,
  utilization: null,
  hourly_cost_usd: config.inference.hourlyCostUsd,
  endpoint: primaryUrl(),
};

export function getLatestTelemetry() {
  return { ...latestTelemetry };
}

async function refreshVllm(base) {
  const root = base.replace(/\/v1$/, '');
  const models = await requestJson({
    method: 'GET',
    url: `${root}/v1/models`,
    timeout: config.upstreamTimeoutMs,
  });
  let metrics = {};
  try {
    const text = await requestJson({
      method: 'GET',
      url: `${root}/metrics`,
      timeout: config.upstreamTimeoutMs,
      headers: { accept: 'text/plain' },
    });
    if (typeof text === 'string') {
      const m = text.match(/vllm:avg_generation_throughput_toks_per_s\s+([\d.]+)/);
      if (m) metrics.tokensPerSecond = Number(m[1]);
    }
  } catch {
    /* metrics optional */
  }
  return {
    timestamp: Date.now(),
    live: true,
    source: 'rtx5090',
    backend: 'vllm',
    models: (models.data || []).map((m) => m.id),
    tokensPerSecond: metrics.tokensPerSecond ?? null,
    utilization: null,
    hourly_cost_usd: config.inference.hourlyCostUsd,
    endpoint: base,
    raw: models,
  };
}

async function refreshOllama(base) {
  const data = await requestJson({
    method: 'GET',
    url: `${base}/api/ps`,
    timeout: config.upstreamTimeoutMs,
  });
  return {
    timestamp: Date.now(),
    live: true,
    source: 'rtx5090',
    backend: 'ollama',
    models: data.models || [],
    vram_used: data.vram_used ?? data.memory ?? null,
    endpoint: base,
    raw: data,
  };
}

export async function refreshTelemetry() {
  const url = primaryUrl();
  try {
    latestTelemetry = isVllm(url) ? await refreshVllm(url) : await refreshOllama(url);
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
  await refreshTelemetry();
  return {
    live: latestTelemetry.live,
    source: 'rtx5090',
    backend: latestTelemetry.backend,
    endpoint: primaryUrl(),
  };
}
