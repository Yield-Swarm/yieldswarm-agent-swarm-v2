/**
 * Helix Chain API — activation status, genesis control, IoTeX yield routing.
 */

import { Router } from 'express';
import { activateHelixChain, getHelixStatus } from '../adapters/helix.js';
import {
  receiveCrossChainYield,
  receiveIotexHubYield,
  listIotexInflowEvents,
  getHelixIotexRoutingStatus,
  normalizeYieldDestination,
} from '../adapters/iotexYield.js';
import { loadTreasuryManifest } from '../lib/treasury-manifest.js';
import {
  getHelixDeltaTelemetry,
  setHelixDeltaThrottle,
  resetHelixDeltaSimulation,
} from '../adapters/helixDeltaV5.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'helix adapter failure' });
    });
  };
}

/** GET /api/helix/delta-v5/telemetry — antimatter + expansion layer snapshot */
router.get('/delta-v5/telemetry', asyncRoute(async (_req, res) => {
  res.json(getHelixDeltaTelemetry());
}));

/** POST /api/helix/delta-v5/throttle — set simulation throttle 0–1 */
router.post('/delta-v5/throttle', asyncRoute(async (req, res) => {
  setHelixDeltaThrottle(req.body?.throttle ?? 0.65);
  res.json(getHelixDeltaTelemetry());
}));

/** POST /api/helix/delta-v5/reset — reset antimatter simulation */
router.post('/delta-v5/reset', asyncRoute(async (_req, res) => {
  resetHelixDeltaSimulation();
  res.json(getHelixDeltaTelemetry());
}));

/** GET /api/helix/status — live Helix Chain activation state */
router.get('/status', asyncRoute(async (_req, res) => {
  const data = await getHelixStatus();
  res.json(data);
}));

/** GET /api/helix/health — lightweight probe for load balancers */
router.get('/health', asyncRoute(async (_req, res) => {
  const data = await getHelixStatus();
  res.status(data.activated ? 200 : 503).json({
    service: 'helix-chain',
    activated: data.activated,
    phase: data.phase,
    readinessScore: data.readinessScore,
  });
}));

/**
 * POST /api/helix/activate — persist genesis receipt and mark chain active.
 * Body: { force?: boolean, source?: string }
 */
router.post('/activate', asyncRoute(async (req, res) => {
  const result = await activateHelixChain({
    force: Boolean(req.body?.force),
    source: req.body?.source || 'api',
  });
  res.status(result.alreadyActive ? 200 : 201).json(result);
}));

/** GET /api/helix/treasury/manifest — Treasury Manifest v2 */
router.get('/treasury/manifest', asyncRoute(async (_req, res) => {
  res.json(loadTreasuryManifest());
}));

/** GET /api/helix/iotex/status — IoTeX hub readiness */
router.get('/iotex/status', asyncRoute(async (_req, res) => {
  const status = getHelixIotexRoutingStatus();
  res.json({
    ready: status.iotexHub.configured,
    treasury: status.iotexHub.primary,
    btcBridge: status.iotexHub.btcBridge,
    inflowCount: status.recentInflowCount,
    supportedDestinations: status.supportedDestinations,
    manifestVersion: status.iotexHub.manifestVersion,
  });
}));

/** GET /api/helix/iotex/inflows — recent IoTeX yield inflow events */
router.get('/iotex/inflows', asyncRoute(async (req, res) => {
  const limit = Number(req.query.limit) || 50;
  const agentId = req.query.agentId || undefined;
  res.json({ events: listIotexInflowEvents({ limit, agentId }) });
}));

/**
 * POST /api/helix/yield/receive — route cross-chain yield to IoTeX or BTC bridge.
 * Body: { amount, asset?, sourceChain, destination?, sourceTx?, agentId?, btcSplitBps? }
 */
router.post('/yield/receive', asyncRoute(async (req, res) => {
  const body = req.body || {};

  if (body.btcSplitBps != null) {
    const hub = receiveIotexHubYield({
      agentId: body.agentId || 'helix-agent',
      totalAmount: body.amount,
      btcSplitBps: body.btcSplitBps,
    });
    return res.status(201).json(hub);
  }

  const destination = normalizeYieldDestination(body.destination || 'iotex_treasury');
  const result = receiveCrossChainYield({
    agentId: body.agentId || 'helix-agent',
    amount: String(body.amount),
    currency: body.asset || body.currency || 'IOTX',
    destination,
    sourceChain: body.sourceChain || 'helix',
    txHash: body.sourceTx || body.txHash || null,
    metadata: body.metadata || {},
  });

  const routing = result.routing;
  const publicDestination =
    routing.destination === 'iotex' ? 'iotex_treasury' : 'btc_via_iopay';

  res.status(201).json({
    ok: result.ok,
    chain: 'iotex',
    destination: publicDestination,
    address: routing.address,
    amount: result.event.amount,
    asset: result.event.currency,
    sourceChain: result.event.sourceChain,
    sourceTx: result.event.txHash,
    agentId: result.event.agentId,
    event: {
      type: result.event.type,
      chain: 'iotex',
      destination: publicDestination,
      address: routing.address,
      amount: result.event.amount,
      asset: result.event.currency,
      sourceChain: result.event.sourceChain,
      sourceTx: result.event.txHash,
      agentId: result.event.agentId,
      timestamp: result.event.receivedAt,
    },
  });
}));

export default router;
