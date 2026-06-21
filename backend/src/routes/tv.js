import { Router } from 'express';
import { buildTvDashboard } from '../adapters/tvDashboard.js';

const router = Router();

router.get('/dashboard', async (_req, res) => {
  try {
    const data = await buildTvDashboard();
    res.json({ ok: true, data });
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message || 'tv dashboard failed' });
  }
});

export default router;
