/**
 * DePIN / Geominer / IoTeX API routes.
 *
 * POST /api/sync              — miner telemetry upsert (ethyswarm@proton.me etc.)
 * GET  /api/depin/checklist   — intro + daily brew progress
 * POST /api/depin/checklist   — mark checklist item complete
 * POST /api/iotex/ingest      — W3bstream Proof-of-Presence relay
 * POST /api/depin/claim       — authoritative PoE claim (rate-limited)
 * GET  /api/depin/consensus   — 100-round HELIX smoke test
 */

import { Router } from 'express';
import * as depinStore from '../adapters/depinStore.js';
import * as iotex from '../adapters/iotex.js';
import { computeHardenedPoEEmission } from '../lib/poeMath.js';
import { consumeToken } from '../lib/rateLimiter.js';
import { runConsensusSmokeTest } from '../lib/consensusRunner.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 500).json({ error: err.message || 'internal error' });
    });
  };
}

function requireEmail(body) {
  const email = body?.email;
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    const err = new Error('valid email required');
    err.status = 400;
    throw err;
  }
  return email.toLowerCase();
}

router.get('/healthz', (_req, res) => {
  res.status(200).json({
    status: 'ACTIVE',
    infrastructure: 'helix-nexus-chain-bridge',
    time: new Date().toISOString(),
  });
});

router.post('/sync', asyncRoute(async (req, res) => {
  const email = requireEmail(req.body);
  const rateKey = `sync:${email}`;
  if (!consumeToken(rateKey, { capacity: 10, refillPerSecond: 0.1 })) {
    return res.status(429).json({ error: 'Rate limit exceeded' });
  }

  const profile = await depinStore.syncMinerProfile({
    email,
    plan: req.body.plan,
    currentBalance: req.body.currentBalance,
    geomines: req.body.geomines,
    geodrops: req.body.geodrops,
    surveys: req.body.surveys,
    spentGeoclaims: req.body.spentGeoclaims,
    spentGeodrops: req.body.spentGeodrops,
    spentSweepstakes: req.body.spentSweepstakes,
  });

  res.json({ success: true, profile });
}));

router.get('/depin/checklist', asyncRoute(async (req, res) => {
  const email = req.query.email;
  if (!email) return res.status(400).json({ error: 'email query param required' });
  const checklist = await depinStore.getChecklist(String(email));
  res.json({ success: true, checklist });
}));

router.post('/depin/checklist', asyncRoute(async (req, res) => {
  const email = requireEmail(req.body);
  const { phase, taskId } = req.body;
  if (!phase || !taskId) return res.status(400).json({ error: 'phase and taskId required' });
  const checklist = await depinStore.completeChecklistItem(email, { phase, taskId });
  res.json({ success: true, checklist });
}));

router.post('/iotex/ingest', asyncRoute(async (req, res) => {
  const deviceId = req.body.deviceId || process.env.IOTEX_DEVICE_ID;
  if (!deviceId) return res.status(400).json({ error: 'deviceId required' });

  const result = await iotex.ingestW3bstreamEvent({
    deviceId,
    payload: req.body.payload || req.body,
    timestamp: req.body.timestamp,
  });
  res.status(result.accepted ? 200 : 502).json(result);
}));

router.post('/depin/claim', asyncRoute(async (req, res) => {
  const email = requireEmail(req.body);
  const wallet = req.body.walletAddress;
  if (!wallet) return res.status(400).json({ error: 'walletAddress required' });

  const rateKey = `claim:${wallet}`;
  if (!consumeToken(rateKey, { capacity: 5, refillPerSecond: 1 / 60 })) {
    return res.status(429).json({ error: 'Rate limit saturated. Execution denied.' });
  }

  const action = req.body.actionData || {};
  const deltaTime = Number(action.deltaTime ?? req.body.deltaTime ?? 120);
  const emission = computeHardenedPoEEmission(
    action.baseFactor ?? 1.5,
    action.enemyLevel ?? 1,
    deltaTime,
  );

  res.json({
    success: true,
    email,
    walletAddress: wallet,
    amountNano: emission.toString(),
    amountDisplay: (Number(emission) / 1_000_000_000).toFixed(4),
    authoritativeDelta: Math.min(Math.max(deltaTime, 1), 3600),
    note: 'BOC signing requires SERVER_ED25519_PRIVATE_KEY in Vault — wire TON adapter for mainnet',
  });
}));

router.get('/depin/consensus', asyncRoute(async (req, res) => {
  const rounds = Math.min(Math.max(Number(req.query.rounds) || 100, 1), 100);
  const result = runConsensusSmokeTest(rounds);
  res.status(result.ok ? 200 : 500).json(result);
}));

router.get('/iotex/status', asyncRoute(async (_req, res) => {
  const status = await iotex.ping();
  res.json(status);
}));

export default router;
