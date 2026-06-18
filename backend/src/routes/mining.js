/**
 * Mining telemetry routes — OpenClaw pure-credit arbitrage → Helix pillars 5 + 7.
 */

import { Router } from 'express';
import * as mining from '../adapters/mining.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 500).json({ error: err.message || 'mining failure' });
    });
  };
}

router.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'mining' });
});

router.get('/summary', asyncRoute(async (_req, res) => {
  res.json(await mining.getMiningSummary());
}));

router.post('/telemetry', asyncRoute(async (req, res) => {
  const result = mining.ingestMiningTelemetry(req.body || {});
  res.status(202).json(result);
}));

router.post('/throttle', asyncRoute(async (req, res) => {
  res.json(mining.applyMiningThrottle(req.body || {}));
}));

export default router;
