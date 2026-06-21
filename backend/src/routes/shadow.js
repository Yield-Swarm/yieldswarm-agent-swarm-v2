/**
 * Shadow Chain API — Solenoid 3 Arena (Kyle's chain).
 */

import { Router } from 'express';
import * as shadow from '../adapters/shadow.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'shadow chain failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await shadow.ping());
}));

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(await shadow.getShadowStatus());
}));

router.get('/vault/injection/:provider', asyncRoute(async (req, res) => {
  const provider = req.params.provider || 'akash';
  res.json(await shadow.getVaultInjection(provider));
}));

export default router;
