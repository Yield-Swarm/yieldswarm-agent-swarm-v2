/**
 * Kairo API routes — driver identity, signed telemetry, contribution stats, rides.
 */

import { Router } from 'express';
import * as kairo from '../adapters/kairo.js';
import * as akash from '../adapters/akash.js';
import * as rides from '../adapters/kairoRides.js';
import { calculateKairoFare } from '../lib/kairoFare.js';

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

/** Fare quote from distance/duration (same math as Next.js /api/kairo/fare). */
router.post('/fare/quote', asyncRoute(async (req, res) => {
  const distanceKm = Number(req.body?.distanceKm ?? req.body?.distance_km ?? 0);
  const durationMin = Number(req.body?.durationMin ?? req.body?.duration_min ?? 0);
  if (distanceKm <= 0 && durationMin <= 0) {
    return res.status(400).json({ error: 'distanceKm or durationMin required' });
  }
  const breakdown = calculateKairoFare({ distanceKm, durationMin });
  res.json({ ok: true, data: breakdown });
}));

router.get('/fare', asyncRoute(async (_req, res) => {
  res.json({
    customerFeePct: 0.01,
    driverMultiplier: 2.0,
    depinRewardRate: Number(process.env.KAIRO_DEPIN_REWARD_RATE || 0.02),
    description: 'Kairo: 1% flat customer fee, 2× driver app pay, DePIN rewards separate',
  });
}));

/** DePIN / Akash worker connectivity for frontend loading states. */
router.get('/depin/status', asyncRoute(async (_req, res) => {
  const workers = await akash.getWorkers();
  res.json({
    live: Boolean(workers.live),
    workersSource: workers.workersSource,
    activeWorkers: workers.activeWorkers ?? 0,
    totalWorkers: workers.totalWorkers ?? 0,
    depinRewardsAvailable: Boolean(workers.live && (workers.activeWorkers ?? 0) > 0),
    message: workers.live
      ? 'Akash workers online — DePIN rewards accruing'
      : 'Waiting for live Akash lease — DePIN rewards pending',
  });
}));

router.post('/rides', asyncRoute(async (req, res) => {
  const ride = rides.createRideRequest(req.body || {});
  res.status(201).json({ ok: true, data: ride });
}));

router.get('/rides/:rideId', asyncRoute(async (req, res) => {
  const ride = rides.getRide(req.params.rideId);
  res.json({ ok: true, data: ride });
}));

router.get('/rides', asyncRoute(async (req, res) => {
  const limit = Number(req.query.limit || 20);
  res.json({ ok: true, data: rides.listRides(limit) });
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

/** Alias consumed by kairo/dashboard and kairo/app clients. */
router.get('/contributions', asyncRoute(async (req, res) => {
  const result = await kairo.getLeaderboard();
  const limit = Number(req.query.limit || 25);
  const drivers = result.data?.drivers || result.data || [];
  res.json({
    live: result.live,
    source: result.source,
    contributions: Array.isArray(drivers) ? drivers.slice(0, limit) : [],
  });
}));

router.post('/telemetry', asyncRoute(async (req, res) => {
  const result = await kairo.submitTelemetry(req.body || {});
  res.status(202).json(result);
}));

export default router;
