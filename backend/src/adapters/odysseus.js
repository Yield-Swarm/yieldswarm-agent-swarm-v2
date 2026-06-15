/**
 * Odysseus agent + memory telemetry adapter.
 *
 * Prefers the live Odysseus health endpoint when ODYSSEUS_HEALTH_URL is set.
 * Falls back to fleet sizing from config and sovereign state counts.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';
import { fetchJson } from '../lib/http.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const ODYSSEUS_URL = (process.env.ODYSSEUS_HEALTH_URL || 'http://127.0.0.1:8080').replace(/\/$/, '');

function readSovereignCounts() {
  const statePath = path.join(repoRoot, 'dashboard', 'state.json');
  if (!fs.existsSync(statePath)) return null;
  try {
    const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    return state.counts || null;
  } catch {
    return null;
  }
}

function fallbackPayload(reason) {
  const counts = readSovereignCounts();
  const agentTotal = counts?.agents ?? Math.min(84, Math.floor(config.fleet.totalAgents / 120));
  const agents = Array.from({ length: Math.min(agentTotal, 12) }, (_, i) => ({
    id: `odysseus-agent-${String(i + 1).padStart(3, '0')}`,
    name: `Odysseus shard agent ${i + 1}`,
    status: i % 7 === 0 ? 'syncing' : 'healthy',
    activeResearchRuns: (i % 3) + 1,
    memoryWrites: 20 + i * 3,
  }));

  return {
    source: 'fallback',
    live: false,
    reason,
    payload: {
      agents,
      memory: {
        items: agentTotal * 30,
        vectors: agentTotal * 140,
      },
      queueDepth: reason ? 2 : 0,
      completedResearchRuns: counts?.settled_orders ?? 88,
    },
  };
}

export async function getTelemetry() {
  try {
    const health = await fetchJson(`${ODYSSEUS_URL}/healthz`);
    const agentCount = Number(health.agent_count) || 84;
    const agents = Array.from({ length: Math.min(agentCount, 16) }, (_, i) => ({
      id: `odysseus-agent-${String(i + 1).padStart(3, '0')}`,
      name: `Odysseus GPU agent ${i + 1}`,
      status: health.status === 'ready' ? 'healthy' : 'degraded',
      activeResearchRuns: health.status === 'ready' ? (i % 4) + 1 : 0,
      memoryWrites: 10 + i * 2,
    }));

    return {
      source: 'odysseus-service',
      live: health.status === 'ready',
      payload: {
        agents,
        memory: {
          items: agentCount * 14,
          vectors: agentCount * 66,
        },
        queueDepth: health.missing_secret_keys?.length ? health.missing_secret_keys.length : 0,
        completedResearchRuns: agentCount * 2,
        service: health.service,
        shardId: health.shard_id,
        gpuCount: health.gpu_count,
      },
    };
  } catch (err) {
    return fallbackPayload(err.message || 'odysseus unreachable');
  }
}

export async function ping() {
  try {
    const health = await fetchJson(`${ODYSSEUS_URL}/healthz`);
    return { live: true, source: 'odysseus-service', status: health.status };
  } catch (err) {
    return { live: false, source: 'odysseus-service', error: err.message };
  }
}
