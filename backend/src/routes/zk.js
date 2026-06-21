/**
 * ZK proof verification API — treasury splits + telemetry bounds.
 */

import { Router } from 'express';

const router = Router();
const KAIRO_API = process.env.KAIRO_API_URL || 'http://127.0.0.1:8091';

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'zk adapter failure' });
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

router.post('/verify', asyncRoute(async (req, res) => {
  const result = await proxyKairo('/api/zk/verify', req.body);
  res.json(result);
}));

router.post('/prove/treasury', asyncRoute(async (req, res) => {
  const result = await proxyKairo('/api/zk/prove/treasury', req.body);
  res.json(result);
}));

router.get('/circuits', asyncRoute(async (_req, res) => {
  res.json({
    circuits: [
      { name: 'entropy_proof', path: 'circuits/entropy_proof.circom', purpose: 'telemetry bounds' },
      { name: 'orchard_treasury', path: 'circuits/orchard_treasury.circom', purpose: '50/30/15/5 split' },
    ],
    formal_verification: 'Recommend Ironwood-style audit for Orchard circuits before MAINNET',
  });
}));

export default router;
