/**
 * Kairo driver API routes — identity registration and signed telemetry ingest.
 */

import { Router } from 'express';
import * as kairo from '../adapters/kairo.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'kairo failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  const ping = await kairo.ping();
  res.status(ping.live ? 200 : 503).json(ping);
}));

router.post('/drivers/register', asyncRoute(async (req, res) => {
  const fp = req.body?.deviceFingerprint;
  const identity = await kairo.registerDriver(fp);
  res.status(201).json(identity);
}));

router.post('/telemetry/ingest', asyncRoute(async (req, res) => {
  const result = await kairo.ingestTelemetry(req.body);
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
}));

router.get('/contributions', asyncRoute(async (req, res) => {
  const limit = Number(req.query.limit) || 50;
  const data = await kairo.listContributions(limit);
  res.json(data);
}));

export default router;
