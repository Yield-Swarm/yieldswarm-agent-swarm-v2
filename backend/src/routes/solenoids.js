/**
 * Solenoid 2 + 3 — Helix treasury and Shadow Chain Arena routes.
 */

import { Router } from 'express';
import { quoteHelixSettlement } from '../adapters/helixBridge.js';
import {
  getHelixTreasuryStatus,
  routeYieldToMiningRoots,
  submitZkSwarmBatch,
} from '../adapters/helixTreasury.js';
import {
  distributeArenaRewards,
  fundArenaPool,
  getArenaStatus,
  registerCompetitor,
  submitArenaScore,
  submitArenaZkBatch,
} from '../adapters/shadowArena.js';

const helixRouter = Router();
const shadowRouter = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'adapter failure' });
    });
  };
}

helixRouter.get('/treasury', asyncRoute(async (_req, res) => {
  res.json(await getHelixTreasuryStatus());
}));

helixRouter.post('/treasury/route', asyncRoute(async (req, res) => {
  const body = req.body || {};
  res.json(await routeYieldToMiningRoots({
    grossLamports: body.grossLamports || body.amount,
    weights: body.weights,
    agentPubkey: body.agentPubkey,
    dryRun: body.dryRun !== false,
  }));
}));

helixRouter.post('/settlement/quote', asyncRoute(async (req, res) => {
  res.json(await quoteHelixSettlement(req.body || {}));
}));

helixRouter.post('/zk/batch', asyncRoute(async (req, res) => {
  res.json(await submitZkSwarmBatch(req.body || {}));
}));

shadowRouter.get('/arena/status', asyncRoute(async (_req, res) => {
  res.json(await getArenaStatus());
}));

shadowRouter.post('/arena/register', asyncRoute(async (req, res) => {
  res.status(201).json(await registerCompetitor(req.body || {}));
}));

shadowRouter.post('/arena/score', asyncRoute(async (req, res) => {
  res.json(await submitArenaScore(req.body || {}));
}));

shadowRouter.post('/arena/zk-batch', asyncRoute(async (req, res) => {
  res.json(await submitArenaZkBatch(req.body || {}));
}));

shadowRouter.post('/arena/rewards', asyncRoute(async (req, res) => {
  res.json(await distributeArenaRewards(req.body || {}));
}));

shadowRouter.post('/arena/fund', asyncRoute(async (req, res) => {
  res.json(await fundArenaPool(req.body?.lamports));
}));

export { helixRouter, shadowRouter };
