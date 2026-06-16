/**
 * Quadrilateral Helix Phase 1 — solenoid + telemetry guard API.
 */

import { Router } from 'express';
import {
  applyThrottle,
  getPentagramRiskSnapshot,
  getSolenoidStatus,
  ingestSsePoolEvent,
  ingestTelemetryPulse,
  pruneContext,
  runAxisMatrix,
  shiftSolenoidMode,
} from '../adapters/solenoid.js';
import { solenoidEngine } from '../middleware/solenoidAnchor.js';

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

/** POST /api/solenoid/shift — elevate quadrilateral → pentagram → 14× elevators */
router.post('/shift', asyncRoute(async (req, res) => {
  const { targetMode } = req.body || {};
  const result = shiftSolenoidMode(targetMode);
  res.json({
    ...result,
    newConfigurationMode: result.mode || result.newConfigurationMode,
    dimensionLevel: result.dimension || result.dimensionLevel,
    stateAnchor: result.stateChainHash || solenoidEngine?.stateChainHash,
  });
}));

/** POST /api/solenoid/ingest — 3D pentagram SSE pool event ingestion */
router.post('/ingest', asyncRoute(async (req, res) => {
  res.json(await ingestSsePoolEvent(req.body || {}));
}));

/** GET /api/solenoid/stream — real-time SSE risk-scoring feed (pentagram layer) */
router.get('/stream', asyncRoute(async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const push = async () => {
    const snapshot = await getPentagramRiskSnapshot();
    const anchor = solenoidEngine.generateStateAnchor(snapshot);
    res.write(
      `data: ${JSON.stringify({ ...snapshot, stateAnchor: anchor.stateAnchor })}\n\n`,
    );
  };

  await push();
  const interval = setInterval(push, Number(process.env.SOLENOID_SSE_INTERVAL_MS || 5000));
  req.on('close', () => clearInterval(interval));
}));

/** POST /api/solenoid/matrix — full 14-pillar axis matrix execution */
router.post('/matrix', asyncRoute(async (req, res) => {
  const result = await runAxisMatrix(req.body || {});
  res.json(result);
}));

export default router;
