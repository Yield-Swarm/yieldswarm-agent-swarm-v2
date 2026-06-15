/**
 * $5M vault telemetry — merges sovereign state with live upstream signals.
 */

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as akash from './akash.js';
import * as treasury from './treasury.js';
import * as emission from './emissionRouter.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const STATE_PATH = process.env.VAULT_STATE_PATH || path.join(REPO_ROOT, 'dashboard', 'state.json');
const TARGET_USD = Number(process.env.VAULT_TARGET_USD || '5000000');

function compoundProjection(navUsd, apy, days = 365) {
  const daily = apy / 365;
  const points = [];
  let value = navUsd;
  for (let d = 0; d <= days; d += 30) {
    points.push({ day: d, nav_usd: Math.round(value) });
    value *= (1 + daily) ** 30;
  }
  return points;
}

export async function getVaultTelemetry() {
  let base = null;
  try {
    const raw = await readFile(STATE_PATH, 'utf8');
    base = JSON.parse(raw);
  } catch {
    base = {
      iteration: 100,
      tick: 0,
      vault_target_usd: TARGET_USD,
      net_worth_usd: 0,
      treasury_usd: 0,
      vault_usd: 0,
      progress: 0,
      target_apy: 0.3,
      blended_apy: 0,
      history: [],
      events: [],
      counts: { workers: 0, active_workers: 0, agents: 10080 },
    };
  }

  const [workers, treasurySplits, emissions] = await Promise.all([
    akash.getWorkers(),
    treasury.getTreasurySplits(),
    emission.getEmissions(),
  ]);

  const liveWorkerCount = workers.totalWorkers || 0;
  const activeWorkers = workers.activeWorkers || 0;
  const treasuryUsd = treasurySplits.live
    ? Number(treasurySplits.totalUsd || treasurySplits.balanceUsd || 0)
    : base.treasury_usd || 0;

  const netWorth = Math.max(
    base.net_worth_usd || 0,
    treasuryUsd + (base.vault_usd || 0) + (base.fleet_credits_usd || 0),
  );
  const progress = Math.min(1, netWorth / TARGET_USD);
  const blendedApy = base.blended_apy || (treasurySplits.weightedApy ?? 0.28);

  const enriched = {
    ...base,
    live: workers.live || treasurySplits.live,
    sources: {
      akash: { connected: workers.live, workers: liveWorkerCount, active: activeWorkers },
      treasury: { connected: treasurySplits.live, totalUsd: treasuryUsd },
      emission: { connected: emissions.live, source: emissions.source },
    },
    net_worth_usd: netWorth,
    treasury_usd: treasuryUsd || base.treasury_usd,
    vault_target_usd: TARGET_USD,
    progress,
    blended_apy: blendedApy,
    healthy_worker_ratio: liveWorkerCount ? activeWorkers / liveWorkerCount : base.healthy_worker_ratio,
    counts: {
      ...(base.counts || {}),
      workers: liveWorkerCount || base.counts?.workers || 0,
      active_workers: activeWorkers || base.counts?.active_workers || 0,
    },
    projections: {
      target_usd: TARGET_USD,
      days_to_target_at_current_apy:
        blendedApy > 0 && netWorth < TARGET_USD
          ? Math.ceil(Math.log(TARGET_USD / Math.max(netWorth, 1)) / Math.log(1 + blendedApy / 365))
          : 0,
      compound_curve: compoundProjection(netWorth, blendedApy),
    },
    updated_at: Date.now() / 1000,
    generatedAt: new Date().toISOString(),
  };

  return enriched;
}
