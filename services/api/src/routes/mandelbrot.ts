import { Router } from 'express';
import {
  ingestToMandelbrot,
  getStats,
  getShardNodes,
  getIngestLog,
} from '../services/mandelbrot-pipeline.js';
import type { MandelbrotIngestRequest } from '../models/mandelbrot.js';

export const mandelbrotRouter = Router();

mandelbrotRouter.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'mandelbrot-pipeline', ...getStats() });
});

mandelbrotRouter.get('/stats', (_req, res) => {
  res.json(getStats());
});

mandelbrotRouter.get('/nodes', (req, res) => {
  const shardId = req.query.shardId
    ? parseInt(req.query.shardId as string)
    : undefined;
  res.json(getShardNodes(shardId));
});

mandelbrotRouter.post('/ingest', (req, res) => {
  const body = req.body as MandelbrotIngestRequest;
  if (!body.driverId || !body.telemetry || !body.signature || !body.signerAddress) {
    res.status(400).json({
      error: 'driverId, telemetry, signature, and signerAddress required',
    });
    return;
  }

  const record = ingestToMandelbrot(body);
  if (!record) {
    res.status(401).json({ error: 'Signature verification failed' });
    return;
  }

  res.status(201).json(record);
});

mandelbrotRouter.get('/ingest', (req, res) => {
  const driverId = req.query.driverId as string | undefined;
  const limit = parseInt(req.query.limit as string) || 100;
  res.json(getIngestLog(driverId, limit));
});
