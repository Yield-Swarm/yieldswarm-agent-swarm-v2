/**
 * Rewards API — reshard, assemble, sweep to treasury wallets.
 */

import { Router } from 'express';
import * as rewards from '../adapters/rewards.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'rewards failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await rewards.ping());
}));

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(await rewards.getRewardsStatus());
}));

router.post('/reshard', asyncRoute(async (_req, res) => {
  res.json(await rewards.runRewardsReshard());
}));

router.post('/assemble', asyncRoute(async (_req, res) => {
  res.json(await rewards.runRewardsAssemble());
}));

router.post('/sweep', asyncRoute(async (req, res) => {
  const full = req.query.full === '1' || req.body?.full === true;
  res.json(full ? await rewards.runRewardsFull() : await rewards.runRewardsSweep());
}));

router.post('/full', asyncRoute(async (_req, res) => {
  res.json(await rewards.runRewardsFull());
}));

export default router;
