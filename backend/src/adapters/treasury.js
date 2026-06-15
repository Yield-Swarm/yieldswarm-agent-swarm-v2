/**
 * Treasury splits telemetry.
 *
 * Reports the treasury's on-chain SOL balance and projects it across the
 * configured split policy (operations / stakers / buyback / reserve). When the
 * treasury address is unset or the RPC is unreachable we fall back to a
 * deterministic figure flagged as a fallback.
 */

import config from '../config.js';
import { getSolBalance } from './solana.js';

const FALLBACK_TREASURY_SOL = 1850.0;

export async function getTreasurySplits() {
  const balance = config.solana.treasury
    ? await getSolBalance(config.solana.treasury)
    : { live: false, sol: 0, error: 'no TREASURY_ADDRESS configured' };

  const live = balance.live;
  const totalSol = live ? balance.sol : FALLBACK_TREASURY_SOL;

  const bps = config.treasurySplitsBps;
  const totalBps = Object.values(bps).reduce((a, b) => a + b, 0) || 10000;

  const splits = Object.entries(bps).map(([name, value]) => ({
    bucket: name,
    bps: value,
    pct: Number(((value / totalBps) * 100).toFixed(2)),
    sol: Number(((totalSol * value) / totalBps).toFixed(4)),
  }));

  return {
    source: live ? 'solana-rpc' : 'fallback',
    live,
    treasuryAddress: config.solana.treasury || null,
    totalSol: Number(totalSol.toFixed(4)),
    totalBps,
    splits,
    error: live ? null : balance.error,
  };
}
