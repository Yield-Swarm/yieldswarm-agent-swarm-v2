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
import * as integrations from '../adapters/integrations.js';
import { getVaultTelemetry } from '../adapters/vaultTelemetry.js';
import { toAkashTelemetryPayload, toOdysseusTelemetryPayload } from '../adapters/telemetryFormat.js';

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
  const [akashPing, solanaPing, odysseusPing] = await Promise.all([
    akash.ping(),
    solana.ping(),
    odysseus.ping(),
  ]);
  const ok = akashPing.live || solanaPing.live || odysseusPing.live;
  res.status(ok ? 200 : 503).json({
    status: ok ? 'ok' : 'degraded',
    time: new Date().toISOString(),
    upstreams: { akash: akashPing, solana: solanaPing, odysseus: odysseusPing },
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

router.get('/brain/status', asyncRoute(async (_req, res) => {
  const data = await cache.get('odysseus:brain', () => odysseus.getBrainStatus());
  res.json(data);
}));

router.get('/models/recommend', asyncRoute(async (req, res) => {
  const data = await cache.get(
    `odysseus:recommend:${req.query.task || 'chat'}`,
    () => odysseus.getModelRecommendation(req.query),
  );
  res.json(data);
}));

router.get('/models/routes', asyncRoute(async (_req, res) => {
  const data = await cache.get('odysseus:models:routes', () => odysseus.getModelRoutes());
  res.json(data);
}));

router.get('/integrations/health', asyncRoute(async (_req, res) => {
  const data = await cache.get('integrations:health', () => integrations.getIntegrationsHealth());
  res.json(data);
}));

router.get('/governance/consensus/status', asyncRoute(async (_req, res) => {
  const data = await cache.get('governance:status', () => integrations.getGovernanceStatus());
  res.json(data);
}));

router.post('/governance/consensus/run', asyncRoute(async (req, res) => {
  const data = await integrations.runGovernanceConsensus(req.body || {});
  res.json(data);
}));

router.get('/auth/session', asyncRoute(async (_req, res) => {
  res.json({ authenticated: false, user: null, mode: process.env.AUTH_MODE || 'demo' });
}));

router.post('/auth/odysseus/handoff', asyncRoute(async (_req, res) => {
  res.json({
    redirectUrl: config.odysseus.workspaceUrl,
    handoffToken: null,
    message: 'Direct workspace redirect — configure Vault OIDC for production SSO',
  });
}));

router.get('/vault/telemetry', asyncRoute(async (_req, res) => {
  const data = await getVaultTelemetry();
  res.json(data);
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
 */
router.get('/arena/overview', asyncRoute(async (_req, res) => {
  const [workers, emissions, treasurySplits, board, odysseusSnap] = await Promise.all([
    cache.get('akash:workers', () => akash.getWorkers()),
    cache.get('telemetry:emission', () => emission.getEmissions()),
    cache.get('telemetry:treasury', () => treasury.getTreasurySplits()),
    cache.get('telemetry:leaderboard:default', () => leaderboard.getLeaderboard({ limit: 10 })),
    cache.get('odysseus:telemetry', () => odysseus.getTelemetry()),
  ]);

  const connections = {
    akashWorkers: { connected: workers.live, source: workers.source },
    emissionRouter: { connected: emissions.live, source: emissions.source },
    treasury: { connected: treasurySplits.live, source: treasurySplits.source },
    leaderboard: { connected: board.live, source: board.source },
    odysseus: { connected: odysseusSnap.live, source: odysseusSnap.source },
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
    odysseus: odysseusSnap,
  });
}));

export default router;
