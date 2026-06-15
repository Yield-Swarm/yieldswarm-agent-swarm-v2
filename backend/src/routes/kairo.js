/**
 * Kairo API proxy routes — mounted on the integration server.
 * Proxies to the Kairo Python API or serves cached contribution data.
 */

import { Router } from 'express';
import config from '../config.js';

const router = Router();
const KAIRO_API = config.kairoApiUrl || 'http://localhost:3001';

async function proxyToKairo(path, options = {}) {
  const url = `${KAIRO_API}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...options.headers },
  });
  const body = await res.json();
  return { status: res.status, body };
}

router.get('/kairo/health', async (_req, res) => {
  try {
    const { status, body } = await proxyToKairo('/api/kairo/health');
    res.status(status).json(body);
  } catch (err) {
    res.status(503).json({ status: 'degraded', error: err.message, service: 'kairo' });
  }
});

router.get('/kairo/contributions', async (req, res) => {
  try {
    const qs = req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : '';
    const { status, body } = await proxyToKairo(`/api/kairo/contributions${qs}`);
    res.status(status).json(body);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.post('/kairo/telemetry', async (req, res) => {
  try {
    const { status, body } = await proxyToKairo('/api/kairo/telemetry', {
      method: 'POST',
      body: JSON.stringify(req.body),
    });
    res.status(status).json(body);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

export default router;
