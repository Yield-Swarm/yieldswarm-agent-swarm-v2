/**
 * Sovereign $5M vault telemetry — reads iteration-100 state + live adapters.
 */

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as akash from '../adapters/akash.js';
import * as treasury from '../adapters/treasury.js';
import * as emission from '../adapters/emissionRouter.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const STATE_PATH = path.join(repoRoot, 'dashboard', 'state.json');
const TARGET_USD = 5_000_000;

async function loadSovereignState() {
  try {
    const raw = await readFile(STATE_PATH, 'utf8');
    return JSON.parse(raw);
  } catch {
    return { net_worth_usd: 0, progress: 0, blended_apy: 0.08 };
  }
}

export async function getSovereignOverview() {
  const [workers, splits, emissions, state] = await Promise.all([
    akash.getWorkers(),
    treasury.getTreasurySplits(),
    emission.getEmissions(),
    loadSovereignState(),
  ]);

  const vaultUsd = Number(state.net_worth_usd ?? state.vault_usd ?? 0);
  const progress = Math.min(100, (vaultUsd / TARGET_USD) * 100);

  return {
    generatedAt: new Date().toISOString(),
    targetUsd: TARGET_USD,
    vaultUsd,
    progressPercent: progress,
    blendedApy: state.blended_apy ?? 0,
    projected90d: vaultUsd * (1 + (state.blended_apy ?? 0.08) * 0.25),
    sovereignState: state,
    akash: workers,
    treasury: splits,
    emissionRouter: emissions,
    live: workers.live || splits.live,
  };
}
