/**
 * Helix Chain duadilateral router — routes all solenoid sources ↔ Base, ETH, TON, TAO, AVAX.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const routesPath = path.join(repoRoot, 'config', 'helix', 'chain-routes.json');
const statePath = path.join(repoRoot, 'dashboard', 'helix-routes-state.json');

let cachedRoutes = null;

export async function loadChainRoutesConfig() {
  if (cachedRoutes) return cachedRoutes;
  const raw = await fs.readFile(routesPath, 'utf8');
  cachedRoutes = JSON.parse(raw);
  return cachedRoutes;
}

function firstEnv(keys) {
  for (const key of keys) {
    const val = process.env[key];
    if (val && val !== '[REDACTED]' && !val.startsWith('your_')) return val;
  }
  return null;
}

function sourceConfigured(sourceDef) {
  const envKey = sourceDef.endpoint_env;
  if (!envKey) return true;
  const url = process.env[envKey];
  return Boolean(url && url !== '[REDACTED]');
}

function targetConfigured(targetDef) {
  return Boolean(firstEnv(targetDef.rpc_env || []));
}

async function probeEvm(rpcUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  try {
    const res = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'eth_blockNumber', params: [] }),
      signal: controller.signal,
    });
    if (!res.ok) return { live: false, error: `HTTP ${res.status}` };
    const data = await res.json();
    return { live: Boolean(data.result), block: data.result || null };
  } catch (err) {
    return { live: false, error: err.message || 'probe failed' };
  } finally {
    clearTimeout(timer);
  }
}

async function probeTon(apiBase, apiKey) {
  const base = apiBase.replace(/\/$/, '');
  const url = `${base}/v2/blockchain/masterchain-head`;
  const headers = { Accept: 'application/json' };
  if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  try {
    const res = await fetch(url, { headers, signal: controller.signal });
    if (!res.ok) return { live: false, error: `HTTP ${res.status}` };
    const data = await res.json();
    return { live: Boolean(data?.seqno != null), block: data?.seqno ?? null };
  } catch (err) {
    return { live: false, error: err.message || 'probe failed' };
  } finally {
    clearTimeout(timer);
  }
}

async function probeSubtensor(rpcUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  try {
    const res = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'system_health', params: [] }),
      signal: controller.signal,
    });
    if (!res.ok) return { live: false, error: `HTTP ${res.status}` };
    const data = await res.json();
    const peers = data?.result?.peers;
    return { live: data?.result?.isSyncing != null, peers: peers ?? null };
  } catch (err) {
    return { live: false, error: err.message || 'probe failed' };
  } finally {
    clearTimeout(timer);
  }
}

async function probeTarget(targetKey, targetDef) {
  const rpc = firstEnv(targetDef.rpc_env || []);
  if (!rpc) {
    return { configured: false, live: false, rpc: null };
  }
  let probe;
  switch (targetDef.type) {
    case 'evm':
      probe = await probeEvm(rpc);
      break;
    case 'ton':
      probe = await probeTon(rpc, process.env[targetDef.api_key_env] || process.env.TON_API_KEY);
      break;
    case 'subtensor':
      probe = await probeSubtensor(rpc);
      break;
    default:
      probe = { live: false, error: 'unknown chain type' };
  }
  return {
    configured: true,
    live: probe.live,
    rpc: rpc.replace(/\/v3\/[^/]+$/, '/v3/***'),
    ...probe,
  };
}

export async function getTargetHealth() {
  const cfg = await loadChainRoutesConfig();
  const targets = {};
  await Promise.all(
    Object.entries(cfg.targets).map(async ([key, def]) => {
      targets[key] = { ...def, health: await probeTarget(key, def) };
    }),
  );
  return targets;
}

export async function resolveDuadilaterals(options = {}) {
  const cfg = await loadChainRoutesConfig();
  const probe = options.probe !== false;
  const targetHealth = probe ? await getTargetHealth() : {};
  const persisted = options.persisted || (await loadRoutesState());

  const routes = cfg.duadilaterals.map((route) => {
    const sourceDef = cfg.sources[route.source];
    const targetDef = cfg.targets[route.target];
    const sourceOk = sourceConfigured(sourceDef);
    const targetOk = targetConfigured(targetDef);
    const health = targetHealth[route.target]?.health;
    const live = probe ? Boolean(health?.live) : false;
    const configured = sourceOk && targetOk;
    const forceArmed = persisted.armed && persisted.routes?.[route.id];
    const armed = config.helix.enabled && (forceArmed || configured);

    let status = 'pending';
    if (armed && live) status = 'live';
    else if (armed) status = 'armed';
    else if (configured) status = 'configured';

    return {
      id: route.id,
      source: route.source,
      target: route.target,
      lane: route.lane,
      priority: route.priority,
      bidirectional: true,
      duadilateral: `${route.source}↔${route.target}`,
      source_name: sourceDef?.name,
      target_chain: targetDef?.network,
      target_symbol: targetDef?.native_symbol,
      chain_id: targetDef?.chain_id,
      status,
      armed,
      live,
      treasury: process.env[targetDef?.treasury_env] || null,
      bridge: targetDef?.bridge,
      explorer: targetDef?.explorer,
    };
  });

  const liveCount = routes.filter((r) => r.status === 'live').length;
  const armedCount = routes.filter((r) => r.armed).length;

  return {
    policy: cfg.policy,
    sources: Object.keys(cfg.sources),
    targets: Object.keys(cfg.targets),
    route_count: routes.length,
    live_count: liveCount,
    armed_count: armedCount,
    helix_enabled: config.helix.enabled,
    routes,
    targets_health: targetHealth,
    persisted_armed: persisted.armed || false,
    generated_at: new Date().toISOString(),
  };
}

export async function loadRoutesState() {
  try {
    const raw = await fs.readFile(statePath, 'utf8');
    return JSON.parse(raw);
  } catch {
    return { armed: false, routes: {} };
  }
}

export async function saveRoutesState(state) {
  await fs.mkdir(path.dirname(statePath), { recursive: true });
  await fs.writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
  return state;
}

/**
 * Arm all duadilateral routes (persists receipt; requires HELIX_CHAIN_ENABLED=1).
 */
export async function armAllDuadilaterals(options = {}) {
  const overview = await resolveDuadilaterals({ probe: true });
  const now = new Date().toISOString();

  const state = {
    armed: true,
    armed_at: now,
    armed_by: options.source || 'api',
    policy: overview.policy,
    route_count: overview.route_count,
    live_count: overview.live_count,
    routes: Object.fromEntries(
      overview.routes.map((r) => [
        r.id,
        {
          status: r.status,
          duadilateral: r.duadilateral,
          target: r.target,
          lane: r.lane,
          armed_at: now,
        },
      ]),
    ),
  };

  await saveRoutesState(state);

  return {
    ok: true,
    armed_at: now,
    message: 'All Helix duadilateral routes armed → Base, ETH, TON, TAO, AVAX',
    overview,
    state,
  };
}

export default {
  loadChainRoutesConfig,
  resolveDuadilaterals,
  getTargetHealth,
  armAllDuadilaterals,
  loadRoutesState,
  saveRoutesState,
};
