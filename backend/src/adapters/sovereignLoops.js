/**
 * Sovereign Loop API adapter — bridges manager to HTTP + telemetry feeds.
 */

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getHelixTreasuryStatus } from './helixTreasury.js';
import { getSovereignState } from './sovereign.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);

const {
  getSovereignLoopManager,
  initSovereignLoopEngine: bootSovereignLoopEngine,
  assertSovereignCredentials,
  LOOP_STATES,
} = require(path.join(repoRoot, 'src', 'infrastructure', 'sovereign-loop', 'SovereignLoopManager.js'));

let booted = false;

async function ensureEngine() {
  const mgr = getSovereignLoopManager();
  if (!booted) {
    await mgr.load();
    booted = true;
  }
  return mgr;
}

async function buildTelemetryFeed() {
  const [sovereign, treasury] = await Promise.all([
    getSovereignState().catch(() => ({})),
    getHelixTreasuryStatus().catch(() => ({})),
  ]);

  const vaultUsd = sovereign.vault_usd ?? sovereign.net_worth_usd ?? 0;
  const treasuryUsd = sovereign.treasury_usd ?? vaultUsd * 0.3;

  return {
    consolidated_usd: vaultUsd + treasuryUsd,
    vault_usd: vaultUsd,
    nexus: vaultUsd * 0.4,
    helix: treasuryUsd * 0.35,
    shadow: treasuryUsd * 0.15,
    iotex: treasuryUsd * 0.1,
    mining_roots: treasury.miningRoots || {},
  };
}

export async function getSovereignLoopsStatus() {
  const mgr = await ensureEngine();
  return mgr.snapshot();
}

export async function runSovereignLoopTick() {
  const mgr = await ensureEngine();
  const feed = await buildTelemetryFeed();
  const anomaly = {
    penning_trap_integrity: Number(process.env.HELIX_PENNING_TRAP_INTEGRITY || 0.88),
    connectivity_ok: true,
  };
  return mgr.tick(feed, anomaly);
}

export async function startSovereignLoopDaemon() {
  await bootSovereignLoopEngine();
  return getSovereignLoopsStatus();
}

export async function stopSovereignLoopDaemon() {
  const mgr = await ensureEngine();
  return mgr.stopDaemon();
}

export async function forceSovereignRebalance() {
  const mgr = await ensureEngine();
  return mgr.forceRebalance();
}

export async function forceSovereignReplicate() {
  const mgr = await ensureEngine();
  return mgr.forceReplicate();
}

export async function forceSovereignPatch() {
  const mgr = await ensureEngine();
  return mgr.forcePatch();
}

export async function pauseResetSovereignLoops() {
  const mgr = await ensureEngine();
  return mgr.pauseAndReset();
}

export function checkSovereignLoopCredentials() {
  try {
    return { ok: true, ...assertSovereignCredentials() };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

export { LOOP_STATES, getSovereignLoopManager, bootSovereignLoopEngine as initSovereignLoopEngine };
