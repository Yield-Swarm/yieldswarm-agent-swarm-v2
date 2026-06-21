/**
 * IoT Hub API — FWA_37KN9S-IoT device registry, monitoring, coordinator sync.
 */

import { Router } from 'express';
import * as iot from '../adapters/iot.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'iot hub failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await iot.ping());
}));

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(await iot.getIotStatus());
}));

router.get('/devices', asyncRoute(async (_req, res) => {
  res.json(await iot.listDevices());
}));

router.get('/devices/:deviceId/check', asyncRoute(async (req, res) => {
  res.json(await iot.checkDevice(req.params.deviceId));
}));

router.post('/register', asyncRoute(async (_req, res) => {
  res.status(201).json(await iot.registerDevices());
}));

router.post('/monitor', asyncRoute(async (_req, res) => {
  res.json(await iot.monitorDevices());
}));

router.post('/sync', asyncRoute(async (_req, res) => {
  res.json(await iot.syncCoordinator());
}));

export default router;
