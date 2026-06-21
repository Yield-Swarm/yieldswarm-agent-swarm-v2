/**
 * Unified command dashboard API — TV + mobile + omnichannel.
 */

import { Router } from 'express';
import { getCommandOverview } from '../adapters/commandDashboard.js';
import { getDomainsOverview } from '../adapters/unstoppableDomains.js';
import {
  activateLudacrisMayhem,
  getLudacrisMayhemStatus,
} from '../adapters/ludacrisMayhem.js';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'command adapter failure' });
    });
  };
}

/** GET /api/command/overview — full fused dashboard payload */
router.get('/overview', asyncRoute(async (_req, res) => {
  res.json(await getCommandOverview());
}));

/** GET /api/command/elevators — 14 spiritual pillar texts */
router.get('/elevators', asyncRoute(async (_req, res) => {
  const raw = await fs.readFile(
    path.join(REPO_ROOT, 'config', 'spiritual-elevators.json'),
    'utf8',
  );
  res.json(JSON.parse(raw));
}));

/** GET /api/command/domains — Unstoppable Domains status */
router.get('/domains', asyncRoute(async (_req, res) => {
  res.json(await getDomainsOverview());
}));

/** GET /api/command/health — lightweight TV poll endpoint */
router.get('/health', asyncRoute(async (_req, res) => {
  const overview = await getCommandOverview();
  const mayhem = await getLudacrisMayhemStatus();
  res.json({
    status: overview.system.overall,
    mayhem: mayhem.activated ? 'ludacris_live' : 'standby',
    timestamp: overview.timestamp,
    solenoids: Object.fromEntries(
      Object.entries(overview.solenoids).map(([k, v]) => [k, v.status]),
    ),
  });
}));

/** GET /api/command/mayhem — Ludacris Mayhem Mode status */
router.get('/mayhem', asyncRoute(async (_req, res) => {
  res.json(await getLudacrisMayhemStatus());
}));

/** POST /api/command/mayhem/activate — arm full live wire */
router.post('/mayhem/activate', asyncRoute(async (req, res) => {
  res.status(201).json(await activateLudacrisMayhem({
    source: req.body?.source || 'api',
  }));
}));

export default router;
