/**
 * Mining fleet API — auth, fleet status, reward routing, deploy control.
 */

import { Router } from 'express';
import {
  getMiningAuthSummary,
  getRewardRoutes,
  readMiningStatus,
  runMiningCommand,
} from '../adapters/miningFleet.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'mining adapter failure' });
    });
  };
}

function requireMiningAuth(req, res, next) {
  const auth = getMiningAuthSummary();
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  const apiKey = process.env.MINING_API_KEY || process.env.AGENTSWARM_MASTER_KEY;
  if (auth.ok) {
    if (apiKey && token && token === apiKey) return next();
    if (!apiKey || process.env.MINING_AUTH_SKIP === '1') return next();
    if (token === apiKey) return next();
  }
  if (process.env.MINING_AUTH_SKIP === '1') return next();
  return res.status(401).json({ error: 'mining auth required', auth });
}

/** GET /api/mining/auth — auth bootstrap status */
router.get('/auth', asyncRoute(async (_req, res) => {
  res.json({
    service: 'mining-auth',
    ...getMiningAuthSummary(),
    reward_routes: getRewardRoutes(),
  });
}));

/** GET /api/mining/status — fleet + miner status */
router.get('/status', asyncRoute(async (_req, res) => {
  const cached = await readMiningStatus();
  if (cached) {
    return res.json(cached);
  }
  const { data } = await runMiningCommand('status');
  res.json(data);
}));

/** GET /api/mining/rewards — payout wallet routing table */
router.get('/rewards', asyncRoute(async (_req, res) => {
  res.json(getRewardRoutes());
}));

/** POST /api/mining/deploy — production bootstrap (auth required) */
router.post('/deploy', requireMiningAuth, asyncRoute(async (_req, res) => {
  const { data, code } = await runMiningCommand('deploy');
  res.status(code === 0 ? 200 : 502).json(data);
}));

/** POST /api/mining/start — start miners */
router.post('/start', requireMiningAuth, asyncRoute(async (req, res) => {
  const miner = req.body?.miner;
  const args = miner ? ['--miner', miner] : [];
  const { data, code } = await runMiningCommand('start', args);
  res.status(code === 0 ? 200 : 502).json(data);
}));

/** POST /api/mining/stop — stop miners */
router.post('/stop', requireMiningAuth, asyncRoute(async (req, res) => {
  const miner = req.body?.miner;
  const args = miner ? ['--miner', miner] : [];
  const { data, code } = await runMiningCommand('stop', args);
  res.status(code === 0 ? 200 : 502).json(data);
}));

/** POST /api/mining/hotload — write configs + start kaspa/qubic/xmr stack */
router.post('/hotload', requireMiningAuth, asyncRoute(async (req, res) => {
  const miners = req.body?.miners || ['kaspa', 'qubic', 'monero'];
  const results = {};
  for (const name of miners) {
    const { data, code } = await runMiningCommand('start', ['--miner', name]);
    results[name] = { code, data };
  }
  const { data: hashpower } = await runMiningCommand('hashpower');
  res.json({ ok: true, results, hashpower });
}));

/** GET /api/mining/hashpower — fleet hashpower estimates */
router.get('/hashpower', asyncRoute(async (_req, res) => {
  const { data, code } = await runMiningCommand('hashpower');
  res.status(code === 0 ? 200 : 502).json(data);
}));

/** GET /api/mining/profitability — top coins for tier */
router.get('/profitability', asyncRoute(async (req, res) => {
  const tier = req.query.tier || 'h100_sxm';
  const { data, code } = await runMiningCommand('profitability', ['--tier', String(tier)]);
  res.status(code === 0 ? 200 : 502).json(data);
}));

/** GET /api/mining/benchmark — live nvidia-smi + fleet estimates */
router.get('/benchmark', asyncRoute(async (_req, res) => {
  const { data, code } = await runMiningCommand('benchmark');
  res.status(code === 0 ? 200 : 502).json(data);
}));

export default router;
