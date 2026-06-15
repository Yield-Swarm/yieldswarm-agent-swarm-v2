/**
 * Treasury splits telemetry.
 *
 * Reports the treasury's on-chain SOL balance and projects it across the
 * configured split policy (operations / stakers / buyback / reserve). When the
 * treasury address is unset or the RPC is unreachable we fall back to a
 * deterministic figure flagged as a fallback.
 */

import config from '../config.js';
import { splitAmount } from '../lib/great-delta-split.js';
import { getSolBalance } from './solana.js';

const FALLBACK_TREASURY_SOL = 1850.0;

export async function getTreasurySplits() {
  const balance = config.solana.treasury
    ? await getSolBalance(config.solana.treasury)
    : { live: false, sol: 0, error: 'no TREASURY_ADDRESS configured' };

  const live = balance.live;
  const totalSol = live ? balance.sol : FALLBACK_TREASURY_SOL;

  const splits = splitAmount(totalSol, config.treasurySplitsBps).map((row) => ({
    bucket: row.bucket,
    label: row.label,
    bps: row.bps,
    pct: row.pct,
    sol: Number(row.amount.toFixed(4)),
  }));
  const totalBps = splits.reduce((sum, row) => sum + row.bps, 0) || 10_000;

  return {
    source: live ? 'solana-rpc' : 'fallback',
    live,
    treasuryAddress: config.solana.treasury || null,
    totalSol: Number(totalSol.toFixed(4)),
    totalBps,
    splitPolicy: '50/30/15/5',
    splits,
    error: live ? null : balance.error,
  };
}
