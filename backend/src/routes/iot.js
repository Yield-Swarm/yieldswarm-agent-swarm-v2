import { Router } from 'express';
import * as iotRegistry from '../adapters/iotRegistry.js';

const router = Router();

router.get('/devices', async (_req, res) => {
  const result = await iotRegistry.getIoTSummary();
  if (!result.ok) {
    res.status(502).json({ ok: false, error: result.error });
    return;
  }
  res.json({ ok: true, data: result.data });
});

router.get('/summary', async (_req, res) => {
  const result = await iotRegistry.getIoTSummary();
  if (!result.ok) {
    res.status(502).json({ ok: false, error: result.error });
    return;
  }
  const { devices, ...summary } = result.data;
  res.json({ ok: true, data: summary });
});

export default router;
