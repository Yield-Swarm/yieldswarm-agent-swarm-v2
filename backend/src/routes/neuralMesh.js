/**
 * Neural mesh + physical API mesh routes.
 */
import { Router } from 'express';
import {
  getNeuralMeshOverview,
  runNeuralMeshMatrix,
} from '../adapters/neuralMesh.js';
import { getTeslaMeshStatus } from '../adapters/teslaFleet.js';
import { getStarlinkStatus, starlinkFetchTerminal } from '../adapters/starlink.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'neural mesh failure' });
    });
  };
}

/** GET /api/neural-mesh/status — tri-solenoid + 14 elevators + API registry */
router.get('/status', asyncRoute(async (_req, res) => {
  res.json(getNeuralMeshOverview());
}));

/** POST /api/neural-mesh/matrix — 14-lane quadrilateral matrix */
router.post('/matrix', asyncRoute(async (req, res) => {
  res.json(await runNeuralMeshMatrix(req.body || {}));
}));

/** GET /api/neural-mesh/tesla — Tesla mesh node summary */
router.get('/tesla', asyncRoute(async (_req, res) => {
  res.json(getTeslaMeshStatus());
}));

/** GET /api/neural-mesh/starlink — Starlink backhaul status */
router.get('/starlink', asyncRoute(async (_req, res) => {
  res.json(getStarlinkStatus());
}));

/** GET /api/neural-mesh/starlink/:terminalId */
router.get('/starlink/:terminalId', asyncRoute(async (req, res) => {
  res.json(await starlinkFetchTerminal(req.params.terminalId));
}));

export default router;
