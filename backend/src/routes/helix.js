/**
 * Helix Chain API — activation status and genesis control.
 */

import { Router } from 'express';
import { activateHelixChain, getHelixStatus } from '../adapters/helix.js';
import { armAllDuadilaterals, loadRoutesState, resolveDuadilaterals } from '../adapters/helixChainRouter.js';

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
  let routes = null;
  if (req.body?.arm_routes !== false) {
    routes = await armAllDuadilaterals({ source: req.body?.source || 'api' });
  }
  res.status(result.alreadyActive ? 200 : 201).json({ ...result, routes });
}));

/** GET /api/helix/routes — all duadilateral routes to Base, ETH, TON, TAO, AVAX */
router.get('/routes', asyncRoute(async (req, res) => {
  const probe = req.query.probe !== '0';
  const state = await loadRoutesState();
  const data = await resolveDuadilaterals({ probe, persisted: state });
  res.json({ ...data, persisted: state });
}));

/** POST /api/helix/routes/arm — arm all duadilateral lanes */
router.post('/routes/arm', asyncRoute(async (req, res) => {
  const result = await armAllDuadilaterals({ source: req.body?.source || 'api' });
  res.status(201).json(result);
}));

export default router;
