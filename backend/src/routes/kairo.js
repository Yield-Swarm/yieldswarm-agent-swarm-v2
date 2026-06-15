/**
 * Kairo API routes — driver identity, signed telemetry, contribution stats.
 */

import { Router } from 'express';
import * as kairo from '../adapters/kairo.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'kairo upstream failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await kairo.ping());
}));

router.post('/drivers', asyncRoute(async (req, res) => {
  const result = await kairo.registerDriver(req.body || {});
  res.status(201).json(result);
}));

router.get('/drivers/:driverId/contribution', asyncRoute(async (req, res) => {
  const fare = Number(req.query.trip_fare_usd || 0);
  const result = await kairo.getContribution(req.params.driverId, fare);
  res.json(result);
}));

router.get('/contribution/leaderboard', asyncRoute(async (_req, res) => {
  const result = await kairo.getLeaderboard();
  res.json(result);
}));

router.post('/telemetry', asyncRoute(async (req, res) => {
  const result = await kairo.submitTelemetry(req.body || {});
  res.status(202).json(result);
}));

export default router;
