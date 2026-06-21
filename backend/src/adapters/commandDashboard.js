/**
 * Unified command dashboard adapter — fuses all three solenoids + treasury + elevators.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getNexusStatus } from './nexus.js';
import { getHelixStatus } from './helix.js';
import { getHelixTreasuryStatus } from './helixTreasury.js';
import { getArenaStatus } from './shadowArena.js';
import { getVaultTelemetry } from './vaultTelemetry.js';
import { getDomainsOverview } from './unstoppableDomains.js';
import * as akash from './akash.js';
import * as solana from './solana.js';
import { getSovereignLoopsStatus } from './sovereignLoops.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const ELEVATORS_PATH = path.join(REPO_ROOT, 'config', 'spiritual-elevators.json');

let elevatorsCache = null;

async function loadElevators() {
  if (elevatorsCache) return elevatorsCache;
  const raw = await fs.readFile(ELEVATORS_PATH, 'utf8');
  elevatorsCache = JSON.parse(raw);
  return elevatorsCache;
}

function healthFrom(parts) {
  const scores = parts.map((p) => (p?.ok ? 1 : p?.live ? 1 : 0));
  const avg = scores.reduce((a, b) => a + b, 0) / Math.max(scores.length, 1);
  if (avg >= 0.75) return 'healthy';
  if (avg >= 0.4) return 'degraded';
  return 'critical';
}

export async function getCommandOverview() {
  const [
    nexus,
    helix,
    treasury,
    shadow,
    vault,
    domains,
    akashWorkers,
    solanaPing,
    elevators,
    sovereignLoops,
  ] = await Promise.all([
    getNexusStatus().catch((e) => ({ error: e.message, ok: false })),
    getHelixStatus().catch((e) => ({ error: e.message, ok: false })),
    getHelixTreasuryStatus().catch((e) => ({ error: e.message, ok: false })),
    getArenaStatus().catch((e) => ({ error: e.message, ok: false })),
    getVaultTelemetry().catch((e) => ({ error: e.message, ok: false })),
    getDomainsOverview().catch((e) => ({ error: e.message, configured: false })),
    akash.getWorkers().catch(() => ({ workers: [], live: false })),
    solana.ping().catch(() => ({ live: false })),
    loadElevators(),
    getSovereignLoopsStatus().catch((e) => ({ error: e.message, state: 'unavailable' })),
  ]);

  const agentCount = nexus?.registry?.agentCount ?? 0;
  const maxAgents = nexus?.registry?.maxAgents ?? 521;

  const solenoids = {
    nexus: {
      id: 'nexus',
      name: 'Nexus Chain',
      status: nexus?.globalPaused ? 'paused' : 'active',
      agents: `${agentCount}/${maxAgents}`,
      vault: nexus?.vault?.configured ?? false,
    },
    helix: {
      id: 'helix',
      name: 'Helix Reverberator',
      status: helix?.activated ? 'active' : helix?.phase || 'pending',
      miningRoots: Object.keys(treasury?.miningRoots || {}).length,
      iotex: treasury?.miningRoots?.iotex || null,
    },
    shadow: {
      id: 'shadow',
      name: 'Shadow Chain',
      owner: shadow?.owner || 'kyle',
      status: 'active',
      competitors: shadow?.competitorCount ?? 0,
      rewardPool: shadow?.rewardPoolLamports ?? 0,
    },
  };

  const treasuryBalances = {
    nexus_solana: treasury?.nexusTreasury?.solana || null,
    mining_roots: treasury?.miningRoots || {},
    iotex_hub: treasury?.iotexHub || {},
    vault_usd: vault?.vault_usd ?? vault?.vaultUsd ?? null,
    vault_target_usd: vault?.vault_target_usd ?? vault?.vaultTargetUsd ?? 5_000_000,
    vault_progress: vault?.progress ?? null,
  };

  const systemHealth = {
    overall: healthFrom([
      { ok: !nexus?.error },
      { live: helix?.activated || helix?.readinessScore > 0 },
      { ok: !shadow?.error },
      { live: solanaPing?.live },
      { live: akashWorkers?.live },
      { configured: domains?.configured },
    ]),
    solana: solanaPing,
    akash: { live: akashWorkers?.live, workers: akashWorkers?.workers?.length ?? 0 },
    vault: { configured: Boolean(process.env.VAULT_ADDR), telemetry: vault?.live ?? false },
    domains: { configured: domains?.configured, live: domains?.liveCount },
  };

  return {
    timestamp: new Date().toISOString(),
    solenoids,
    treasury: treasuryBalances,
    spiritual_elevators: elevators.elevators,
    system: systemHealth,
    domains,
    agents: {
      registered: agentCount,
      cap: maxAgents,
      slots_remaining: maxAgents - agentCount,
    },
    helix_detail: {
      phase: helix?.phase,
      activated: helix?.activated,
      yslr: helix?.yslr,
    },
    nexus_resources: nexus?.resources || null,
    sovereign_loops: {
      version: sovereignLoops?.version ?? '1.0.0-Beta',
      state: sovereignLoops?.state ?? '—',
      tickCount: sovereignLoops?.tickCount ?? 0,
      credentialsOk: sovereignLoops?.credentialsOk ?? false,
      chainBalances: sovereignLoops?.chainBalances ?? {},
      recent_logs: (sovereignLoops?.logs ?? []).slice(-5),
    },
  };
}
