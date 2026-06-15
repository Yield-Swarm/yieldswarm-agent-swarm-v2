/**
 * $5M vault / sovereign treasury telemetry for the vault dashboard.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');

function readJson(relativePath) {
  const full = path.join(repoRoot, relativePath);
  if (!fs.existsSync(full)) return null;
  try {
    return JSON.parse(fs.readFileSync(full, 'utf8'));
  } catch {
    return null;
  }
}

export function getVaultTelemetry() {
  const sovereign = readJson('dashboard/state.json');
  if (sovereign) {
    return {
      live: true,
      source: 'sovereign-state',
      iteration: sovereign.iteration,
      tick: sovereign.tick,
      vaultUsd: sovereign.vault_usd,
      treasuryUsd: sovereign.treasury_usd,
      netWorthUsd: sovereign.net_worth_usd,
      vaultTargetUsd: sovereign.vault_target_usd ?? 5_000_000,
      progress: sovereign.progress,
      blendedApy: sovereign.blended_apy,
      targetApy: sovereign.target_apy,
      fleetNetHourlyUsd: sovereign.fleet_net_hourly_usd,
      healthyWorkerRatio: sovereign.healthy_worker_ratio,
      counts: sovereign.counts,
      updatedAt: sovereign.updated_at
        ? new Date(sovereign.updated_at * 1000).toISOString()
        : new Date().toISOString(),
    };
  }

  const iteration = readJson('dashboard/iteration_100_state.json');
  if (iteration) {
    return {
      live: false,
      source: 'iteration-100-state',
      vaultUsd: iteration.vault_usd ?? 0,
      treasuryUsd: iteration.treasury_usd ?? 0,
      netWorthUsd: (iteration.vault_usd ?? 0) + (iteration.treasury_usd ?? 0),
      vaultTargetUsd: 5_000_000,
      progress: (iteration.vault_usd ?? 0) / 5_000_000,
      counts: { agents: (iteration.agents || []).length },
      updatedAt: new Date().toISOString(),
    };
  }

  return {
    live: false,
    source: 'fallback',
    vaultUsd: 0,
    treasuryUsd: 0,
    netWorthUsd: 0,
    vaultTargetUsd: 5_000_000,
    progress: 0,
    updatedAt: new Date().toISOString(),
  };
}
