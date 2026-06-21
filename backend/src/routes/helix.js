/**
 * Helix Chain API — activation status and genesis control.
 */

import { Router } from 'express';
import { activateHelixChain, getHelixStatus } from '../adapters/helix.js';
import { quoteHelixSettlement } from '../adapters/helixBridge.js';
import {
  getHelixTreasuryStatus,
  routeYieldToMiningRoots,
  submitZkSwarmBatch,
} from '../adapters/helixTreasury.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'helix adapter failure' });
    });
  };
}

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

/** GET /api/helix/treasury — Mining Roots + IoTeX hub manifest */
router.get('/treasury', asyncRoute(async (_req, res) => {
  res.json(await getHelixTreasuryStatus());
}));

/** POST /api/helix/treasury/route — route yield to all Mining Roots */
router.post('/treasury/route', asyncRoute(async (req, res) => {
  const body = req.body || {};
  res.json(await routeYieldToMiningRoots({
    grossLamports: body.grossLamports || body.amount,
    weights: body.weights,
    agentPubkey: body.agentPubkey,
    dryRun: body.dryRun !== false,
  }));
}));

/** POST /api/helix/settlement/quote — dry-run harvest settlement */
router.post('/settlement/quote', asyncRoute(async (req, res) => {
  res.json(await quoteHelixSettlement(req.body || {}));
}));

/** POST /api/helix/zk/batch — ZK-Swarm proof batch */
router.post('/zk/batch', asyncRoute(async (req, res) => {
  res.json(await submitZkSwarmBatch(req.body || {}));
}));

export default router;
