/**
 * Genesis / Web5 manifest API
 */

import { Router } from 'express';
import { getGenesisManifestLive, loadGenesisManifest } from '../adapters/genesisManifest.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'genesis adapter failure' });
    });
  };
}

/** GET /api/genesis/manifest — Web5 unified field manifest + live Helix hash */
router.get('/manifest', asyncRoute(async (_req, res) => {
  res.json(await getGenesisManifestLive());
}));

/** GET /api/genesis/beacon — temporal stewardship beacon (day/year/week) */
router.get('/beacon', asyncRoute(async (_req, res) => {
  const m = await loadGenesisManifest();
  res.json({
    motto: m.motto,
    temporal_beacon: m.temporal_beacon,
    equation: m.equation.symbol,
    stewardship: m.stewardship,
    time: new Date().toISOString(),
  });
}));

export default router;
