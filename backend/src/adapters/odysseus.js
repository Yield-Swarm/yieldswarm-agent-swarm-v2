/**
 * Odysseus brain adapter — queries the central orchestration API on Akash workers.
 */

import config from '../config.js';
import { fetchJson } from '../lib/http.js';

const BRAIN_BASE = (process.env.ODYSSEUS_BRAIN_URL || process.env.ODYSSEUS_URL || 'http://127.0.0.1:8080').replace(/\/$/, '');

export async function getTelemetry() {
  if (!config.odysseus.enabled) {
    return fallback('odysseus adapter disabled (ODYSSEUS_ENABLED=false)');
  }

  try {
    const data = await fetchJson(`${BRAIN_BASE}/api/telemetry/odysseus`, {
      timeoutMs: config.upstreamTimeoutMs,
    });
    return { ...data, live: true, source: 'odysseus-brain' };
  } catch (err) {
    return fallback(`odysseus brain upstream error: ${err.message}`);
  }
}

export async function getBrainStatus() {
  return fetchJson(`${BRAIN_BASE}/api/brain/status`, { timeoutMs: config.upstreamTimeoutMs });
}

export async function executeTool(name, arguments_ = {}) {
  return fetchJson(`${BRAIN_BASE}/api/tools/execute`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, arguments: arguments_ }),
    timeoutMs: config.upstreamTimeoutMs,
  });
}

function fallback(reason) {
  return {
    source: 'fallback',
    live: false,
    reason,
    status: 'degraded',
    agents: [],
    memory: { items: 0, vectors: 0, queueDepth: 0 },
    updatedAt: new Date().toISOString(),
  };
}

export async function ping() {
  if (!config.odysseus.enabled) return { live: false, error: 'disabled' };
  try {
    const data = await fetchJson(`${BRAIN_BASE}/healthz`, { timeoutMs: 3000 });
    return { live: data.status === 'ready', status: data.status };
  } catch (err) {
    return { live: false, error: err.message };
  }
}
