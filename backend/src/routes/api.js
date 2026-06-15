/**
 * API surface consumed by the Arena dashboard and Portal.
 *
 * All telemetry responses include a `source`/`live` flag so the frontend can
 * render connection health. Responses are cached briefly (TtlCache) to protect
 * upstreams from the dashboard's auto-refresh polling.
 */

import express, { Router } from 'express';
import config from '../config.js';
import TtlCache from '../lib/cache.js';
import { validateSplitBps, LEGACY_SPLIT_PCT } from '../lib/great-delta-split.js';
import * as akash from '../adapters/akash.js';
import * as emission from '../adapters/emissionRouter.js';
import * as treasury from '../adapters/treasury.js';
import * as greatDelta from '../adapters/greatDelta.js';
import * as leaderboard from '../adapters/leaderboard.js';
import * as solana from '../adapters/solana.js';
import * as odysseus from '../adapters/odysseus.js';
import { getVaultTelemetry } from '../adapters/vault.js';
import { toAkashTelemetryPayload, toOdysseusTelemetryPayload } from '../adapters/telemetryFormat.js';

const router = Router();
const cache = new TtlCache(config.cacheTtlMs);
router.use(express.json({ limit: '32kb' }));

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'upstream failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  const [akashPing, solanaPing] = await Promise.all([akash.ping(), solana.ping()]);
  const ok = akashPing.live || solanaPing.live;
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

/** Static Arena/Portal contract — see frontend/shared/telemetry.js */
router.get('/telemetry/akash', asyncRoute(async (_req, res) => {
  const snapshot = await cache.get('akash:workers', () => akash.getWorkers());
  res.json(toAkashTelemetryPayload(snapshot));
}));

router.get('/telemetry/odysseus', asyncRoute(async (_req, res) => {
  const snapshot = await cache.get('odysseus:telemetry', () => odysseus.getTelemetry());
  res.json(toOdysseusTelemetryPayload(snapshot));
}));

router.get('/vault/telemetry', asyncRoute(async (_req, res) => {
  res.json(getVaultTelemetry());
}));

/** Portal SSO stubs — returns anonymous session until Odysseus auth is wired. */
router.get('/auth/session', asyncRoute(async (_req, res) => {
  res.json({
    authenticated: false,
    provider: null,
    user: null,
    odysseusLinked: false,
    timestamp: new Date().toISOString(),
  });
}));

router.post('/auth/odysseus/handoff', asyncRoute(async (req, res) => {
  res.status(501).json({
    error: 'Odysseus SSO handoff requires Odysseus runtime',
    hint: 'Start docker-compose.odysseus.yml and configure ODYSSEUS_ADMIN_* in Vault',
    received: Boolean(req.body?.token || req.body?.session),
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

router.get('/great-delta/health', asyncRoute(async (_req, res) => {
  validateSplitBps(config.treasurySplitsBps);
  res.json({
    status: 'ok',
    service: 'great-delta',
    policy: '50/30/15/5',
    splitBps: config.treasurySplitsBps,
    legacySplitPct: LEGACY_SPLIT_PCT,
    timestamp: new Date().toISOString(),
  });
}));

router.get('/great-delta/overview', asyncRoute(async (_req, res) => {
  const data = await cache.get('great-delta:overview', () => greatDelta.getGreatDeltaOverview());
  res.json(data);
}));

router.post('/great-delta/telemetry', asyncRoute(async (req, res) => {
  const started = Date.now();
  const event = greatDelta.ingestTelemetryEvent({
    event: req.body?.event || 'heartbeat',
    source: req.body?.source || 'worker',
    sentAt: req.body?.sentAt || null,
    ...(req.body?.agentId ? { agentId: req.body.agentId } : {}),
    ...(req.body?.latencyMs !== undefined ? { latencyMs: req.body.latencyMs } : {}),
  });
  const elapsedMs = Date.now() - started;
  res.json({
    accepted: true,
    event: event.event,
    source: event.source,
    receivedAt: event.receivedAt,
    guardrail: {
      maxMs: 80,
      elapsedMs,
      withinGuardrail: elapsedMs <= 80,
    },
  });
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
 */
router.get('/arena/overview', asyncRoute(async (_req, res) => {
  const [workers, emissions, treasurySplits, board, gd] = await Promise.all([
    cache.get('akash:workers', () => akash.getWorkers()),
    cache.get('telemetry:emission', () => emission.getEmissions()),
    cache.get('telemetry:treasury', () => treasury.getTreasurySplits()),
    cache.get('telemetry:leaderboard:default', () => leaderboard.getLeaderboard({ limit: 10 })),
    cache.get('great-delta:overview', () => greatDelta.getGreatDeltaOverview()),
  ]);

  const connections = {
    akashWorkers: { connected: workers.live, source: workers.source },
    emissionRouter: { connected: emissions.live, source: emissions.source },
    treasury: { connected: treasurySplits.live, source: treasurySplits.source },
    leaderboard: { connected: board.live, source: board.source },
    greatDeltaEvm: { connected: gd.evm?.live ?? false, source: gd.evm?.source ?? 'disabled' },
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
    greatDelta: gd,
    leaderboard: board,
  });
}));

export default router;
