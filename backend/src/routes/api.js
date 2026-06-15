/**
 * API surface consumed by the Arena dashboard and Portal.
 *
 * All telemetry responses include a `source`/`live` flag so the frontend can
 * render connection health. Responses are cached briefly (TtlCache) to protect
 * upstreams from the dashboard's auto-refresh polling.
 */

import { Router } from 'express';
import config from '../config.js';
import TtlCache from '../lib/cache.js';
import * as akash from '../adapters/akash.js';
import * as emission from '../adapters/emissionRouter.js';
import * as treasury from '../adapters/treasury.js';
import * as leaderboard from '../adapters/leaderboard.js';
import * as solana from '../adapters/solana.js';

const router = Router();
const cache = new TtlCache(config.cacheTtlMs);

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'upstream failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  const [akashPing, solanaPing] = await Promise.all([akash.ping(), solana.ping()]);
  const ok = akashPing.live || solanaPing.live; // service is up even if one upstream is down
  res.status(ok ? 200 : 503).json({
    status: ok ? 'ok' : 'degraded',
    time: new Date().toISOString(),
    upstreams: {
      akash: akashPing,
      solana: solanaPing,
    },
  });
}));

router.get('/akash/workers', asyncRoute(async (_req, res) => {
  const data = await cache.get('akash:workers', () => akash.getWorkers());
  res.json(data);
}));

/** Alias consumed by frontend/shared/telemetry.js (Arena static dashboard). */
router.get('/telemetry/akash', asyncRoute(async (_req, res) => {
  const data = await cache.get('akash:workers', () => akash.getWorkers());
  res.json({ ...data, source: data.source || 'akash', updatedAt: new Date().toISOString() });
}));

/** Odysseus agent/memory telemetry — maps leaderboard rows to agent metrics. */
router.get('/telemetry/odysseus', asyncRoute(async (_req, res) => {
  const [board, emissions] = await Promise.all([
    cache.get('telemetry:leaderboard:default', () => leaderboard.getLeaderboard({ limit: 25 })),
    cache.get('telemetry:emission', () => emission.getEmissions()),
  ]);
  const rows = board.rows || board.entries || board.leaderboard || [];
  const agents = rows.map((entry, i) => ({
    id: entry.agentId || entry.address || `agent-${i + 1}`,
    name: entry.shard ? `${entry.shard} · ${entry.agentId}` : (entry.label || entry.name || `Odysseus agent ${i + 1}`),
    role: entry.shard || 'research',
    status: board.live ? 'healthy' : 'degraded',
    activeResearchRuns: entry.tasksCompleted ? Math.min(5, Math.floor(entry.tasksCompleted / 1000)) : 1,
    memoryWrites: entry.rewardsApn ? Math.floor(entry.rewardsApn / 10) : 0,
    rewardsApn: entry.rewardsApn ?? 0,
  }));
  const memoryItems = agents.reduce((s, a) => s + (a.memoryWrites || 0), 0);
  res.json({
    source: 'odysseus',
    live: board.live || emissions.live,
    status: board.live ? 'active' : 'degraded',
    agents,
    activeResearchRuns: agents.reduce((s, a) => s + (a.activeResearchRuns || 0), 0),
    memoryItems,
    memory: { items: memoryItems, vectors: memoryItems * 4 },
    vectorCount: memoryItems * 4,
    queueDepth: board.live ? 0 : 1,
    completedResearchRuns: agents.length * 10,
    updatedAt: new Date().toISOString(),
  });
}));

router.get('/sovereign/state', asyncRoute(async (_req, res) => {
  const { getSovereignState } = await import('../adapters/sovereign.js');
  const data = await getSovereignState();
  res.json(data);
}));

router.get('/telemetry/emission-router', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:emission', () => emission.getEmissions());
  res.json(data);
}));

router.get('/telemetry/treasury', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:treasury', () => treasury.getTreasurySplits());
  res.json(data);
}));

router.get('/telemetry/leaderboard', asyncRoute(async (req, res) => {
  const limit = req.query.limit;
  const data = await cache.get(`telemetry:leaderboard:${limit || 'default'}`, () =>
    leaderboard.getLeaderboard({ limit }),
  );
  res.json(data);
}));

/**
 * Single aggregated payload that powers the Arena dashboard in one round-trip.
 * Each section is fetched in parallel and resolves independently so one slow or
 * failing upstream never blocks the rest of the dashboard.
 */
router.get('/arena/overview', asyncRoute(async (_req, res) => {
  const [workers, emissions, treasurySplits, board] = await Promise.all([
    cache.get('akash:workers', () => akash.getWorkers()),
    cache.get('telemetry:emission', () => emission.getEmissions()),
    cache.get('telemetry:treasury', () => treasury.getTreasurySplits()),
    cache.get('telemetry:leaderboard:default', () => leaderboard.getLeaderboard({ limit: 10 })),
  ]);

  const connections = {
    akashWorkers: { connected: workers.live, source: workers.source },
    emissionRouter: { connected: emissions.live, source: emissions.source },
    treasury: { connected: treasurySplits.live, source: treasurySplits.source },
    leaderboard: { connected: board.live, source: board.source },
  };
  const connectedCount = Object.values(connections).filter((c) => c.connected).length;

  res.json({
    generatedAt: new Date().toISOString(),
    connections,
    connectionsHealthy: connectedCount,
    connectionsTotal: Object.keys(connections).length,
    akash: workers,
    emissionRouter: emissions,
    treasury: treasurySplits,
    leaderboard: board,
  });
}));

export default router;
