/**
 * Sovereign state API — merges simulation state with live telemetry overlays.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';
import * as akash from '../adapters/akash.js';
import * as emission from '../adapters/emissionRouter.js';
import * as treasury from '../adapters/treasury.js';
import { BUCKET_LABELS } from '../lib/great-delta-split.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const statePath = path.join(repoRoot, 'dashboard', 'state.json');

export async function getSovereignState() {
  let base;
  try {
    const raw = await fs.readFile(statePath, 'utf8');
    base = JSON.parse(raw);
  } catch (err) {
    base = {
      tick: 0,
      vault_usd: 0,
      vault_target_usd: 5_000_000,
      treasury_usd: 0,
      net_worth_usd: 0,
      progress: 0,
      target_apy: 0.3,
      blended_apy: 0,
      counts: { workers: 0, agents: 0 },
      events: [],
      history: [],
      updated_at: Date.now() / 1000,
    };
  }

  const [workers, emissions, treasurySplits] = await Promise.all([
    akash.getWorkers(),
    emission.getEmissions(),
    treasury.getTreasurySplits(),
  ]);

  const liveWorkers = workers.workers?.length ?? 0;
  const activeWorkers = workers.workers?.filter((w) =>
    ['active', 'running'].includes(String(w.state || w.status || '').toLowerCase()),
  ).length ?? 0;

  return {
    ...base,
    live_overlay: {
      akash: { connected: workers.live, source: workers.source, workers: liveWorkers, active: activeWorkers },
      emission: {
        connected: emissions.live,
        source: emissions.source,
        perEpoch: emissions.emissionPerEpoch,
        splitPolicy: emissions.splitPolicy || '50/30/15/5',
        routes: emissions.routes || [],
      },
      treasury: {
        connected: treasurySplits.live,
        source: treasurySplits.source,
        totalSol: treasurySplits.totalSol,
        splitPolicy: treasurySplits.splitPolicy || '50/30/15/5',
        splits: (treasurySplits.splits || []).map((row) => ({
          ...row,
          label: row.label || BUCKET_LABELS[row.bucket] || row.bucket,
        })),
      },
      generatedAt: new Date().toISOString(),
    },
    // Enrich counts when live Akash data is available
    counts: {
      ...(base.counts || {}),
      workers: workers.live ? liveWorkers : (base.counts?.workers ?? 0),
      active_workers: workers.live ? activeWorkers : (base.counts?.active_workers ?? 0),
    },
    fleet_net_hourly_usd: workers.live
      ? Number((workers.workers || []).reduce((s, w) => s + (w.netHourlyUsd || 0), 0).toFixed(2))
      : base.fleet_net_hourly_usd,
    progress: base.vault_target_usd
      ? Math.min(1, (base.net_worth_usd || 0) / base.vault_target_usd)
      : base.progress,
  };
}

/** Alias for sovereign router clients expecting overview naming. */
export const getSovereignOverview = getSovereignState;

export default { getSovereignState, getSovereignOverview };
