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
import * as integrations from '../adapters/integrations.js';
import * as dex from '../adapters/dex.js';
import { getVaultTelemetry } from '../adapters/vaultTelemetry.js';
import { toAkashTelemetryPayload, toOdysseusTelemetryPayload } from '../adapters/telemetryFormat.js';
import { getHelixStatus } from '../adapters/helix.js';
import { getZkMayhemStatus } from '../adapters/zkMayhem.js';
import * as crossChain from '../adapters/crossChain.js';
import * as rtx5090 from '../adapters/rtx5090Telemetry.js';
import { routeRequest } from '../infrastructure/odysseus-router.js';
import * as oracle from '../adapters/oracle.js';
import * as dydx from '../adapters/dydx.js';
import * as miningFleet from '../adapters/miningFleet.js';
import * as iotRegistry from '../adapters/iotRegistry.js';
import { getSubsystemSnapshots } from '../adapters/singlePane.js';

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

/** RTX 5090 Ollama hardware telemetry (Arena + sovereign loops) */
router.get('/telemetry/5090', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:5090', () => rtx5090.refreshTelemetry());
  res.json(data);
}));

router.post('/inference/route', asyncRoute(async (req, res) => {
  const { prompt, taskType, priority, agentId } = req.body || {};
  if (!prompt) {
    res.status(400).json({ error: 'prompt required' });
    return;
  }
  const t5090 = await cache.get('telemetry:5090', () => rtx5090.refreshTelemetry());
  const result = await routeRequest(
    String(prompt),
    taskType || 'chat',
    priority || 'normal',
    { rtx5090: t5090, h100: {} },
  );
  res.json(result);
}));

/** Container / GPU telemetry edge route (Arena + sovereign loops) */
router.get('/telemetry/container', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:5090', () => rtx5090.refreshTelemetry());
  res.json({
    ...data,
    service: 'vllm-rtx5090',
    scrapedAt: new Date().toISOString(),
  });
}));

/** Oracle sync status + mutation proof relay */
router.get('/oracle/sync', asyncRoute(async (_req, res) => {
  const data = await cache.get('oracle:status', () => oracle.getOracleStatus());
  res.json(data);
}));

router.post('/oracle/sync', asyncRoute(async (req, res) => {
  const body = req.body || {};
  if (!body.tokenId) {
    res.status(400).json({ error: 'tokenId required' });
    return;
  }
  const result = await oracle.syncMutationProof(body);
  res.json(result);
}));

/** dYdX v4 market + positions (primary trading layer) */
router.get('/trading/dydx/health', asyncRoute(async (_req, res) => {
  const data = await cache.get('dydx:health', () => dydx.getDydxHealth());
  res.json(data);
}));

router.get('/trading/dydx/market/:ticker', asyncRoute(async (req, res) => {
  const ticker = req.params.ticker || 'BTC-USD';
  const data = await cache.get(`dydx:market:${ticker}`, () => dydx.getMarketPrice(ticker));
  res.json(data);
}));

router.get('/trading/dydx/positions', asyncRoute(async (req, res) => {
  const subaccount = req.query.subaccount || req.query.subaccountId;
  const data = await cache.get(`dydx:positions:${subaccount || 'default'}`, () =>
    dydx.getActivePositions(subaccount),
  );
  res.json(data);
}));

/** Helix Chain genesis + YSLR activation telemetry */
router.get('/telemetry/helix', asyncRoute(async (_req, res) => {
  const data = await cache.get('telemetry:helix', () => getHelixStatus());
  res.json(data);
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

router.get('/dex/health', asyncRoute(async (_req, res) => {
  const data = await cache.get('dex:health', () => dex.getDexHealth());
  res.json(data);
}));

router.post('/dex/quote', asyncRoute(async (req, res) => {
  const { chain, ...params } = req.body || {};
  const data = await cache.get(
    `dex:quote:${chain || 'solana'}:${params.input_mint || params.inputMint || 'default'}`,
    async () => {
      if (chain === 'ethereum' || chain === 'evm') {
        return dex.quoteUniswapV4(params);
      }
      return dex.quoteJupiter({
        inputMint: params.input_mint || params.inputMint,
        outputMint: params.output_mint || params.outputMint,
        amount: params.amount,
        slippageBps: params.slippage_bps || params.slippageBps,
      });
    },
  );
  res.json(data);
}));

router.get('/auth/session', asyncRoute(async (_req, res) => {
  const miningAuth = process.env.AGENTSWARM_MASTER_KEY ? 'vault-hmac' : 'demo';
  res.json({
    authenticated: Boolean(process.env.AGENTSWARM_MASTER_KEY && process.env.AGENTSWARM_MASTER_KEY !== '[REDACTED]'),
    user: null,
    mode: process.env.AUTH_MODE || 'vault-approle',
    mining_auth: miningAuth,
    mining_api: '/api/mining/auth',
  });
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

router.get('/cross-chain/health', asyncRoute(async (_req, res) => {
  const ping = await crossChain.ping();
  res.json({ status: ping.live ? 'ok' : 'idle', ...ping, time: new Date().toISOString() });
}));

router.get('/cross-chain/overview', asyncRoute(async (_req, res) => {
  const data = await cache.get('cross-chain:overview', () => crossChain.getCrossChainOverview());
  res.json(data);
}));

router.post('/cross-chain/telemetry', asyncRoute(async (req, res) => {
  const result = await crossChain.ingestTelemetry(req.body || {});
  res.json({ accepted: true, ...result });
}));

/**
 * Single aggregated payload that powers the Arena dashboard in one round-trip.
 */
router.get('/arena/overview', asyncRoute(async (_req, res) => {
  const [workers, emissions, treasurySplits, board, odysseusSnap, gd, helix, xchain, zkMayhem, miningStatus, iotSnap, singlePane] = await Promise.all([
    cache.get('akash:workers', () => akash.getWorkers()),
    cache.get('telemetry:emission', () => emission.getEmissions()),
    cache.get('telemetry:treasury', () => treasury.getTreasurySplits()),
    cache.get('telemetry:leaderboard:default', () => leaderboard.getLeaderboard({ limit: 10 })),
    cache.get('odysseus:telemetry', () => odysseus.getTelemetry()),
    cache.get('great-delta:overview', () => greatDelta.getGreatDeltaOverview()),
    cache.get('telemetry:helix', () => getHelixStatus()),
    cache.get('cross-chain:overview', () => crossChain.getCrossChainOverview()),
    cache.get('telemetry:zk-mayhem', () => getZkMayhemStatus()),
    cache.get('mining:status', () => miningFleet.readMiningStatus()),
    cache.get('iot:summary', () => iotRegistry.getIoTSummary()),
    cache.get('single-pane:snapshot', () => getSubsystemSnapshots()),
  ]);

  const miningAuth = miningFleet.getMiningAuthSummary();
  const miningRewards = miningFleet.getRewardRoutes();
  const iot = iotSnap.ok ? iotSnap.data : { total: 0, online: 0, by_type: {} };

  const connections = {
    akashWorkers: { connected: workers.live, source: workers.source },
    emissionRouter: { connected: emissions.live, source: emissions.source },
    treasury: { connected: treasurySplits.live, source: treasurySplits.source },
    leaderboard: { connected: board.live, source: board.source },
    odysseus: { connected: odysseusSnap.live, source: odysseusSnap.source },
    greatDeltaEvm: { connected: gd.evm?.live ?? false, source: gd.evm?.source ?? 'disabled' },
    helixChain: { connected: helix.activated, source: helix.phase },
    crossChain: { connected: xchain.live, source: xchain.source },
    zkMayhem: { connected: zkMayhem.enabled && zkMayhem.circuitBuilt, source: zkMayhem.service },
    mining: { connected: miningAuth.ok, source: miningAuth.mode },
    iot: { connected: iot.total > 0, source: 'device_registry' },
    node5: { connected: Boolean(singlePane?.prompts?.ready), source: 'single_pane' },
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
    odysseus: odysseusSnap,
    helix,
    crossChain: xchain,
    zkMayhem,
    mining: {
      status: miningStatus,
      auth: miningAuth,
      rewards: miningRewards,
    },
    iot,
    node5: singlePane?.prompts?.prompts?.find((p) => p.slug === 'node5') || null,
    singlePane: {
      promptsReady: singlePane?.prompts?.ready ?? 0,
      promptsTotal: singlePane?.prompts?.total ?? 20,
      surfaces: singlePane?.surfaces ?? {},
    },
  });
}));

export default router;
