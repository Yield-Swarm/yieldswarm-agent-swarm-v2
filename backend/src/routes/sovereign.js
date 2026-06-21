/**
 * Sovereign $5M vault telemetry API + SSE stream + loop engine.
 */

import { Router } from 'express';
import * as sovereign from '../adapters/sovereign.js';
import {
  checkSovereignLoopCredentials,
  getSovereignLoopsStatus,
  runSovereignLoopTick,
  startSovereignLoopDaemon,
  stopSovereignLoopDaemon,
} from '../adapters/sovereignLoops.js';

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

/** GET /api/sovereign/loops — real-time sovereign loop engine state */
router.get('/loops', asyncRoute(async (_req, res) => {
  res.json(await getSovereignLoopsStatus());
}));

/** POST /api/sovereign/loops/tick — manual tick (economic + replication + heal) */
router.post('/loops/tick', asyncRoute(async (_req, res) => {
  res.json(await runSovereignLoopTick());
}));

/** POST /api/sovereign/loops/start — start background daemon */
router.post('/loops/start', asyncRoute(async (_req, res) => {
  res.json(await startSovereignLoopDaemon());
}));

/** POST /api/sovereign/loops/stop */
router.post('/loops/stop', asyncRoute(async (_req, res) => {
  res.json(await stopSovereignLoopDaemon());
}));

/** GET /api/sovereign/loops/credentials */
router.get('/loops/credentials', asyncRoute(async (_req, res) => {
  res.json(checkSovereignLoopCredentials());
}));

export default router;
