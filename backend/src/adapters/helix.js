/**
 * Helix Chain activation adapter.
 *
 * Helix Chain is the cross-execution layer that ties sovereign loops, Great Delta
 * emission routing, Kairo telemetry, and multi-cloud fallback into one operational
 * milestone. Activation persists to dashboard/helix-state.json and is surfaced
 * via /api/helix/* for the Council status page and Arena telemetry.
 */

import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';
import * as akash from './akash.js';
import * as emission from './emissionRouter.js';
import { getVaultTelemetry } from './vaultTelemetry.js';
import { getSovereignState } from './sovereign.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const statePath = path.join(repoRoot, 'dashboard', 'helix-state.json');

const DEFAULT_STATE = {
  activated: false,
  phase: 'genesis-pending',
  genesisHash: null,
  activatedAt: null,
  activatedBy: null,
  yslr: { phase: 'pending', signalsProcessed: 0, lastSignalAt: null },
  tracks: {
    domains: 'pending',
    akash: 'pending',
    terraform: 'pending',
    vault: 'pending',
    sovereign: 'pending',
  },
  receipts: [],
};

export async function loadHelixState() {
  try {
    const raw = await fs.readFile(statePath, 'utf8');
    return { ...DEFAULT_STATE, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

export async function saveHelixState(state) {
  await fs.mkdir(path.dirname(statePath), { recursive: true });
  await fs.writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
  return state;
}

function genesisHash(seed) {
  return crypto.createHash('sha256').update(seed).digest('hex');
}

function bridgeConfigured() {
  const key = config.helix.bridgeKey;
  return Boolean(key && key !== 'your_helix_bridge_key_here');
}

function trackStatusFromEnv() {
  return {
    domains: process.env.APP_URL || process.env.NEXT_PUBLIC_APP_URL ? 'ready' : 'pending',
    akash: config.akash.owner ? 'ready' : 'pending',
    terraform: process.env.TF_CLOUD_ORGANIZATION || process.env.TF_ENABLE_FLY ? 'ready' : 'pending',
    vault: process.env.VAULT_ADDR ? 'ready' : 'pending',
    sovereign: 'ready',
  };
}

/**
 * Full Helix Chain status for dashboards and activation gating.
 */
export async function getHelixStatus() {
  const state = await loadHelixState();
  const envEnabled = config.helix.enabled;
  const activated = envEnabled || state.activated;
  const [sovereign, emissions, vault, workers] = await Promise.all([
    getSovereignState(),
    emission.getEmissions(),
    getVaultTelemetry(),
    akash.getWorkers(),
  ]);

  const readiness = {
    helixEnabled: envEnabled,
    stateActivated: state.activated,
    bridgeKey: bridgeConfigured(),
    emissionRouter:
      Boolean(config.helix.emissionRouter) ||
      Boolean(config.solana.emissionRouter) ||
      Boolean(config.evm.emissionRouter),
    controlPlane: Boolean(config.helix.controlPlaneUrl),
    sovereignLoops: true,
    akashLive: workers.live,
    vaultReachable: Boolean(vault.live),
  };

  const readyCount = Object.values(readiness).filter(Boolean).length;
  const phase = activated
    ? state.phase === 'genesis-pending'
      ? 'genesis-active'
      : state.phase
    : 'genesis-pending';

  return {
    service: 'helix-chain',
    activated,
    phase,
    genesisHash: state.genesisHash,
    activatedAt: state.activatedAt,
    activatedBy: state.activatedBy,
    yslr: {
      ...state.yslr,
      phase: activated ? state.yslr.phase === 'pending' ? 'listening' : state.yslr.phase : 'pending',
    },
    tracks: { ...state.tracks, ...trackStatusFromEnv() },
    readiness,
    readinessScore: `${readyCount}/${Object.keys(readiness).length}`,
    onChainReceipts: {
      emissionRouter: {
        connected: emissions.live || emissions.routerConnected,
        address: config.helix.emissionRouter || config.solana.emissionRouter || config.evm.emissionRouter || null,
        splitPolicy: emissions.splitPolicy || '50/30/15/5',
      },
      treasuryNavUsd: sovereign.net_worth_usd ?? sovereign.vault_usd ?? 0,
    },
    sovereign: {
      progress: sovereign.progress,
      vaultTargetUsd: sovereign.vault_target_usd ?? 5_000_000,
      workers: sovereign.counts?.workers ?? 0,
    },
    generatedAt: new Date().toISOString(),
  };
}

/**
 * Activate Helix Chain — persists genesis receipt and advances YSLR phase.
 */
export async function activateHelixChain(options = {}) {
  const state = await loadHelixState();
  if (state.activated && !options.force) {
    return {
      ok: true,
      alreadyActive: true,
      state,
      status: await getHelixStatus(),
    };
  }

  const now = new Date().toISOString();
  const seed = `helix-genesis:${now}:${options.source || 'api'}:${config.helix.bridgeKey ? 'bridge' : 'open'}`;
  const hash = genesisHash(seed);

  const next = {
    ...state,
    activated: true,
    phase: 'genesis-active',
    genesisHash: hash,
    activatedAt: now,
    activatedBy: options.source || 'api',
    yslr: {
      phase: 'listening',
      signalsProcessed: state.yslr?.signalsProcessed ?? 0,
      lastSignalAt: now,
    },
    tracks: trackStatusFromEnv(),
    receipts: [
      ...(state.receipts || []).slice(-9),
      {
        type: 'genesis',
        hash,
        at: now,
        source: options.source || 'api',
        emissionRouter:
          config.helix.emissionRouter ||
          config.solana.emissionRouter ||
          config.evm.emissionRouter ||
          null,
      },
    ],
  };

  await saveHelixState(next);

  return {
    ok: true,
    alreadyActive: false,
    genesisHash: hash,
    activatedAt: now,
    message: 'Helix Chain activated — sovereign loops and emission routing online',
    status: await getHelixStatus(),
  };
}

export default { getHelixStatus, activateHelixChain, loadHelixState, saveHelixState };
