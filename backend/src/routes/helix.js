/**
 * Helix Chain API — activation status and genesis control.
 */

import { Router } from 'express';
import { activateHelixChain, getHelixStatus } from '../adapters/helix.js';
import { quoteHelixSettlement } from '../adapters/helixBridge.js';

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

/**
 * POST /api/helix/settlement/quote — dry-run harvest quote (Solenoid 2).
 * Body: { agentPubkey?, originChainId?, targetChainId?, amount? }
 */
router.post('/settlement/quote', asyncRoute(async (req, res) => {
  const quote = await quoteHelixSettlement({
    agentPubkey: req.body?.agentPubkey,
    originChainId: req.body?.originChainId,
    targetChainId: req.body?.targetChainId,
    amount: Number(req.body?.amount || 0),
  });
  res.json(quote);
}));

export default router;
