/**
 * Sovereign $5M vault telemetry API + SSE stream.
 */

import { Router } from 'express';
import * as sovereign from '../adapters/sovereign.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'sovereign failure' });
    });
  };
}

router.get('/overview', asyncRoute(async (_req, res) => {
  const data = await sovereign.getSovereignState();
  res.json(data);
}));

router.get('/stream', asyncRoute(async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const push = async () => {
    const data = await sovereign.getSovereignState();
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  await push();
  const interval = setInterval(push, 15000);
  req.on('close', () => clearInterval(interval));
}));

export default router;
