import { Router } from 'express';
import {
  registerDriver,
  getDriver,
  getContribution,
  ingestSignedTelemetry,
  listTelemetry,
  computeShardId,
} from '../services/kairo-identity.js';
import type { TelemetryPayload } from '../models/kairo.js';

export const kairoRouter = Router();

kairoRouter.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'kairo-identity' });
});

kairoRouter.post('/drivers/register', (req, res) => {
  const { deviceId, platform, publicKey } = req.body;
  if (!deviceId || !platform) {
    res.status(400).json({ error: 'deviceId and platform required' });
    return;
  }
  const result = registerDriver({ deviceId, platform, publicKey });
  res.status(201).json(result);
});

kairoRouter.get('/drivers/:driverId', (req, res) => {
  const driver = getDriver(req.params.driverId);
  if (!driver) {
    res.status(404).json({ error: 'Driver not found' });
    return;
  }
  res.json(driver);
});

kairoRouter.get('/drivers/:driverId/contribution', (req, res) => {
  const contrib = getContribution(req.params.driverId);
  if (!contrib) {
    res.status(404).json({ error: 'Driver not found' });
    return;
  }
  res.json(contrib);
});

kairoRouter.post('/telemetry', (req, res) => {
  const { driverId, payload, signature } = req.body as {
    driverId: string;
    payload: TelemetryPayload;
    signature: string;
  };

  if (!driverId || !payload || !signature) {
    res.status(400).json({ error: 'driverId, payload, and signature required' });
    return;
  }

  if (payload.shardId === undefined) {
    payload.shardId = computeShardId(payload.latitude, payload.longitude);
  }

  const record = ingestSignedTelemetry(driverId, payload, signature);
  if (!record) {
    res.status(404).json({ error: 'Driver not found' });
    return;
  }

  res.status(201).json(record);
});

kairoRouter.get('/drivers/:driverId/telemetry', (req, res) => {
  const limit = parseInt(req.query.limit as string) || 50;
  res.json(listTelemetry(req.params.driverId, limit));
});
