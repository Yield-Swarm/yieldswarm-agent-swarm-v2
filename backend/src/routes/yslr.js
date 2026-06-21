/**
 * YSLR encryption API — proxies to Kairo Python API or local L1 fallback.
 */

import { Router } from 'express';
import { createHmac, randomBytes, createHash, createCipheriv } from 'node:crypto';

const router = Router();

const KAIRO_API = process.env.KAIRO_API_URL || 'http://127.0.0.1:8091';

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'yslr adapter failure' });
    });
  };
}

async function proxyKairo(path, body) {
  const resp = await fetch(`${KAIRO_API}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(text || `Kairo API ${resp.status}`);
  }
  return resp.json();
}

/** L1-only fallback when Kairo API unavailable */
function l1Encrypt(data) {
  const key = createHash('sha256')
    .update(process.env.YSLR_CLASSICAL_KEY || 'yieldswarm-yslr-dev-key')
    .digest();
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const pt = Buffer.from(typeof data === 'string' ? data : JSON.stringify(data));
  const ct = Buffer.concat([cipher.update(pt), cipher.final()]);
  const tag = cipher.getAuthTag();
  const hmac = createHmac('sha256', key).update(Buffer.concat([nonce, ct, tag])).digest('hex');
  return {
    version: 1,
    layers: [1],
    nonce: nonce.toString('hex'),
    ciphertext: Buffer.concat([ct, tag]).toString('hex'),
    hmac,
    metadata: { mode: 'l1-fallback' },
  };
}

router.post('/encrypt', asyncRoute(async (req, res) => {
  try {
    const result = await proxyKairo('/api/yslr/encrypt', req.body);
    return res.json(result);
  } catch {
    const envelope = l1Encrypt(req.body?.data ?? '');
    return res.json({ envelope, fallback: true });
  }
}));

router.post('/decrypt', asyncRoute(async (req, res) => {
  const result = await proxyKairo('/api/yslr/decrypt', req.body);
  res.json(result);
}));

router.post('/keys', asyncRoute(async (req, res) => {
  const result = await proxyKairo('/api/yslr/keys', req.body);
  res.status(201).json(result);
}));

router.post('/telemetry', asyncRoute(async (req, res) => {
  const result = await proxyKairo('/api/yslr/telemetry', req.body);
  res.json(result);
}));

router.get('/status', asyncRoute(async (_req, res) => {
  const lockdown = String(process.env.NETWORK_LOCKDOWN_MODE || '').toLowerCase() === 'true';
  res.json({
    service: 'yslr',
    version: 1,
    layers: ['classical', 'orchard-zk', 'pqc-hybrid'],
    lockdown,
    kairo_api: KAIRO_API,
  });
}));

export default router;
