/**
 * Agent leaderboard telemetry.
 *
 * Ranks the swarm's agents by on-chain rewards earned. Where the $APN mint is
 * readable we anchor the leaderboard to the real largest token accounts (a
 * live on-chain signal); otherwise we generate a deterministic ranking flagged
 * as a fallback. Either way the shape is identical so the dashboard renders the
 * same regardless of connectivity.
 */

import config from '../config.js';
import { getTokenLargestAccounts } from './solana.js';

const SHARD_LABELS = ['Kimiclaw', 'SuperGrok', 'Helix', 'Hydrogen', 'Runic', 'Atomic', 'GEOD', 'OpenClaw'];

function seeded(seed) {
  let h = 2166136261 ^ seed;
  h = Math.imul(h ^ (h >>> 15), 2246822507);
  h = Math.imul(h ^ (h >>> 13), 3266489909);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}

function fallbackRows(limit) {
  const rows = [];
  for (let i = 0; i < limit; i++) {
    const shard = SHARD_LABELS[i % SHARD_LABELS.length];
    const rewards = Number((50000 * seeded(i + 1) + (limit - i) * 1200).toFixed(2));
    rows.push({
      rank: i + 1,
      agentId: `${shard.toLowerCase()}-agent-${String(i + 1).padStart(4, '0')}`,
      shard,
      rewardsApn: rewards,
      tasksCompleted: Math.floor(500 + seeded(i + 100) * 5000),
      account: null,
    });
  }
  return rows;
}

export async function getLeaderboard({ limit = 10 } = {}) {
  const cappedLimit = Math.min(Math.max(Number(limit) || 10, 1), 25);
  const largest = await getTokenLargestAccounts(config.solana.apnMint);

  if (largest.live && largest.accounts.length > 0) {
    const rows = largest.accounts.slice(0, cappedLimit).map((acc, i) => ({
      rank: i + 1,
      agentId: `agent-${acc.address.slice(0, 6).toLowerCase()}`,
      shard: SHARD_LABELS[i % SHARD_LABELS.length],
      rewardsApn: Number((acc.uiAmount ?? 0).toFixed(2)),
      tasksCompleted: null,
      account: acc.address,
    }));
    return {
      source: 'solana-rpc',
      live: true,
      mint: config.solana.apnMint,
      totalAgents: config.fleet.totalAgents,
      rows,
      error: null,
    };
  }

  return {
    source: 'fallback',
    live: false,
    mint: config.solana.apnMint,
    totalAgents: config.fleet.totalAgents,
    rows: fallbackRows(cappedLimit),
    error: largest.error || 'on-chain holders unavailable',
  };
}
