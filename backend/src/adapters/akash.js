/**
 * Akash worker telemetry adapter.
 *
 * "Workers" are the compute units the swarm runs on Akash (GPU miners,
 * OpenClaw, Eliza, Gensyn, etc.).
 *
 * Data sources (in order of preference):
 *   1. Akash Console indexer API (https://console-api.akash.network) for live
 *      network capacity + provider health. This is reachable without running a
 *      market-enabled RPC node (public Cosmos REST nodes prune the market
 *      module and return 501 for lease queries), so it is the reliable live
 *      signal that the Arena's Akash connection is healthy.
 *   2. Owner-specific active deployments/leases when AKASH_OWNER_ADDRESS is set
 *      — these become the concrete worker rows.
 *   3. A deterministic sample fleet, used only when the Console API is
 *      unreachable. Always flagged so the dashboard shows the degraded state.
 */

import config from '../config.js';
import { fetchJson, UpstreamError } from '../lib/http.js';

const CONSOLE_API = config.akash.consoleApi;

const FALLBACK_WORKERS = [
  { id: 'openclaw-01', kind: 'orchestrator', region: 'us-west', gpu: null },
  { id: 'gpu-h100-gensyn', kind: 'gpu-miner', region: 'us-central', gpu: 'H100' },
  { id: 'gpu-4090-bminer', kind: 'gpu-miner', region: 'eu-west', gpu: 'RTX4090' },
  { id: 'eliza-agent-host', kind: 'agent-host', region: 'us-east', gpu: null },
  { id: 'lolminer-pool-01', kind: 'gpu-miner', region: 'ap-south', gpu: 'RTX3090' },
];

// Deterministic pseudo-random so sample values are stable across a process run
// but vary per worker — avoids "all identical" placeholder rows.
function seeded(id, salt) {
  let h = 2166136261 ^ salt;
  for (let i = 0; i < id.length; i++) {
    h = Math.imul(h ^ id.charCodeAt(i), 16777619);
  }
  return ((h >>> 0) % 1000) / 1000;
}

function sampleWorkers() {
  return FALLBACK_WORKERS.map((w) => ({
    ...w,
    state: 'active',
    cpuUtil: Number((0.4 + seeded(w.id, 7) * 0.55).toFixed(3)),
    memUtil: Number((0.35 + seeded(w.id, 17) * 0.5).toFixed(3)),
    uptimePct: Number(((0.95 + seeded(w.id, 13) * 0.05) * 100).toFixed(2)),
    hashrateMhs: w.kind === 'gpu-miner' ? Number((60 + seeded(w.id, 23) * 80).toFixed(1)) : null,
    leaseDseq: null,
    provider: null,
  }));
}

function fallbackSnapshot(reason) {
  const workers = sampleWorkers();
  return {
    source: 'fallback',
    live: false,
    workersSource: 'sample',
    reason,
    owner: config.akash.owner || null,
    network: null,
    activeWorkers: workers.length,
    totalWorkers: workers.length,
    workers,
  };
}

async function fetchNetwork() {
  const [capacity, providers] = await Promise.all([
    fetchJson(`${CONSOLE_API}/network-capacity`),
    fetchJson(`${CONSOLE_API}/providers`),
  ]);
  const res = capacity?.resources || {};
  const onlineProviders = (providers || []).filter((p) => p.isOnline);
  const gpuOnline = onlineProviders.reduce((sum, p) => sum + ((p.stats?.gpu?.active || 0) + (p.stats?.gpu?.available || 0)), 0);
  return {
    providersTotal: (providers || []).length,
    providersOnline: onlineProviders.length,
    gpu: res.gpu || null,
    cpu: res.cpu || null,
    gpuOnlineCapacity: gpuOnline,
  };
}

async function fetchOwnerWorkers(owner) {
  // Console indexer: active deployments for an address. 404 => none indexed.
  let deployments = [];
  try {
    const data = await fetchJson(`${CONSOLE_API}/addresses/${owner}/deployments/0?limit=50&reverseSorting=true&status=active`);
    deployments = data?.deployments || data || [];
  } catch (err) {
    if (!(err instanceof UpstreamError && err.status === 404)) throw err;
  }
  if (!Array.isArray(deployments)) return [];
  return deployments.map((d) => {
    const dseq = d.dseq ?? d.deployment?.dseq ?? null;
    const lease = (d.leases && d.leases[0]) || {};
    return {
      id: `akash-${dseq}`,
      kind: 'akash-lease',
      region: lease.provider?.region || null,
      gpu: lease.gpuModels?.[0] || null,
      state: 'active',
      leaseDseq: dseq,
      provider: lease.provider?.address || lease.provider || null,
      cpuUtil: null,
      memUtil: null,
      uptimePct: null,
      hashrateMhs: null,
    };
  });
}

export async function getWorkers() {
  if (!config.akash.enabled) {
    return fallbackSnapshot('akash adapter disabled (AKASH_ENABLED=false)');
  }
  try {
    const network = await fetchNetwork();

    let workers = [];
    let workersSource = 'sample';
    let reason = null;

    if (config.akash.owner) {
      const owned = await fetchOwnerWorkers(config.akash.owner);
      if (owned.length > 0) {
        workers = owned;
        workersSource = 'owner-leases';
      } else {
        workers = sampleWorkers();
        reason = `no active leases indexed for owner ${config.akash.owner}; showing sample fleet`;
      }
    } else {
      workers = sampleWorkers();
      reason = 'no AKASH_OWNER_ADDRESS configured; showing sample fleet (network data is live)';
    }

    return {
      // Live: we have a real connection to Akash (network capacity is real).
      source: 'akash-console',
      live: true,
      workersSource,
      reason,
      owner: config.akash.owner || null,
      network,
      activeWorkers: workers.filter((w) => w.state === 'active').length,
      totalWorkers: workers.length,
      workers,
    };
  } catch (err) {
    return fallbackSnapshot(`akash console upstream error: ${err.message}`);
  }
}

/** Connectivity probe for /api/health. */
export async function ping() {
  if (!config.akash.enabled) return { live: false, error: 'disabled' };
  try {
    await fetchJson(`${CONSOLE_API}/network-capacity`, { timeoutMs: 3000 });
    return { live: true };
  } catch (err) {
    return { live: false, error: err.message };
  }
}
