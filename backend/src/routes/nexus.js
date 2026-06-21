/**
 * Solenoid 1 — Nexus Chain API routes.
 */

import { Router } from 'express';
import {
  allocateNexusResource,
  getNexusBusRecent,
  getNexusStatus,
  publishNexusMessage,
  registerNexusAgent,
  releaseNexusResource,
  setNexusGlobalPause,
} from '../adapters/nexus.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.message?.includes('cap') ? 409 : 502).json({
        error: err.message || 'nexus adapter failure',
      });
    });
  };
}

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(await getNexusStatus());
}));

router.post('/agents/register', asyncRoute(async (req, res) => {
  res.status(201).json(await registerNexusAgent(req.body || {}));
}));

router.post('/resources/allocate', asyncRoute(async (req, res) => {
  res.status(201).json(await allocateNexusResource(req.body || {}));
}));

router.post('/resources/release', asyncRoute(async (req, res) => {
  const id = req.body?.workloadId || req.body?.id;
  res.json(await releaseNexusResource(id));
}));

router.post('/pause', asyncRoute(async (req, res) => {
  res.json(await setNexusGlobalPause(req.body?.paused ?? true));
}));

router.post('/bus/publish', asyncRoute(async (req, res) => {
  res.status(201).json(await publishNexusMessage(req.body || {}));
}));

router.get('/bus/recent', asyncRoute(async (req, res) => {
  const limit = Number(req.query.limit) || 20;
  res.json({ messages: await getNexusBusRecent(req.query.topic, limit) });
}));

export default router;
