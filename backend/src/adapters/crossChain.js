/**
 * Cross-chain execution telemetry adapter.
 * Reads .run/cross-chain-*.json written by services/cross_chain/executor.py
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { splitAmount } from '../lib/great-delta-split.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../../..');
const RUN_DIR = process.env.RUN_DIR || path.join(REPO_ROOT, '.run');

async function readJsonSafe(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export async function getCrossChainOverview() {
  const lastRun = await readJsonSafe(path.join(RUN_DIR, 'cross-chain-last-run.json'));
  const history = await readJsonSafe(path.join(RUN_DIR, 'cross-chain-executions.json'));

  const strategies = lastRun?.receipts
    ? Object.values(lastRun.receipts).map((r) => ({
        job_id: r.job_id,
        kind: r.kind,
        status: r.status,
        venue: r.venue,
        chain: r.chain,
        gross_revenue_usd: r.gross_revenue_usd,
      }))
    : [];

  const treasuryTotals = lastRun?.treasury_totals_usd || {};
  const totalGross = Object.values(treasuryTotals).reduce((a, b) => a + Number(b || 0), 0);
  const projectedSplit = splitAmount(totalGross);

  return {
    live: Boolean(lastRun),
    source: 'cross_chain_executor',
    last_run_at: lastRun?.run_at || null,
    dry_run: lastRun?.dry_run ?? true,
    job_count: lastRun?.job_count || 0,
    strategies,
    treasury_totals_usd: treasuryTotals,
    projected_great_delta_split: projectedSplit,
    receipt_count: history ? Object.keys(history).length : 0,
    venues: {
      uniswap_v4: { chain: 'ethereum', status: 'scaffold' },
      solana: { venues: ['jupiter', 'orca', 'raydium'], status: 'jupiter_quotes' },
      dydx: { chain: 'dydx', status: 'scaffold' },
      pow: { coins: ['bittensor', 'grass', 'flux', 'kaspa'], status: 'bittensor_live' },
      helix_duadilaterals: {
        targets: ['base', 'ethereum', 'ton', 'tao', 'avax'],
        sources: ['nexus', 'helix', 'shadow'],
        status: 'config/helix/chain-routes.json',
      },
    },
  };
}

export async function ping() {
  const overview = await getCrossChainOverview();
  return { live: overview.live, service: 'cross-chain' };
}

export async function ingestTelemetry(payload) {
  const out = path.join(RUN_DIR, 'cross-chain-ingest.json');
  await fs.mkdir(RUN_DIR, { recursive: true });
  const entry = { received_at: Date.now(), ...payload };
  await fs.writeFile(out, JSON.stringify(entry, null, 2));
  return { ok: true, path: out };
}
