/**
 * Quadrilateral Helix Phase 1 — solenoid + telemetry guard API.
 */

import { Router } from 'express';
import {
  applyThrottle,
  getSolenoidStatus,
  ingestTelemetryPulse,
  pruneContext,
  runAxisMatrix,
} from '../adapters/solenoid.js';
import { ingestTeslaFleetTelemetry } from '../adapters/teslaFleet.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'solenoid adapter failure' });
    });
  };
}

/** GET /api/solenoid/status — quadrilateral axis health snapshot */
router.get('/status', asyncRoute(async (_req, res) => {
  res.json(getSolenoidStatus());
}));

/** POST /api/solenoid/throttle — X-axis thermal workload shed (monitor daemon) */
router.post('/throttle', asyncRoute(async (req, res) => {
  res.json(applyThrottle(req.body || {}));
}));

/** POST /api/context/prune — VRAM saturation cache prune */
router.post('/prune', asyncRoute(async (req, res) => {
  res.json(pruneContext(req.body || {}));
}));

/** POST /api/telemetry/pulse — oracle bridge metric pulse per pillar */
router.post('/pulse', asyncRoute(async (req, res) => {
  res.json(ingestTelemetryPulse(req.body || {}));
}));

/** POST /api/telemetry/tesla — Tesla Fleet API ingest (pillar 7) */
router.post('/tesla', asyncRoute(async (req, res) => {
  const result = ingestTeslaFleetTelemetry(req.body || {});
  res.status(result.ok ? 202 : 400).json(result);
}));

/** POST /api/solenoid/matrix — full 14-pillar axis matrix execution */
router.post('/matrix', asyncRoute(async (req, res) => {
  const result = await runAxisMatrix(req.body || {});
  res.json(result);
}));

export default router;
