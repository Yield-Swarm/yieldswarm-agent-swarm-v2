/**
 * Helix Nodes API — Grass-style node layer, lottery tickets, referrals.
 */

import { Router } from 'express';
import * as helixNodes from '../adapters/helixNodes.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ ok: false, error: err.message || 'helix-nodes failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await helixNodes.ping());
}));

router.get('/summary', asyncRoute(async (_req, res) => {
  res.json({ ok: true, ...(await helixNodes.getSummary()) });
}));

router.post('/register', asyncRoute(async (req, res) => {
  const { user_id: userId, referral_code: referralCode, platform } = req.body || {};
  const node = await helixNodes.registerNode({ userId, referralCode, platform });
  res.json({ ok: true, node });
}));

router.post('/heartbeat', asyncRoute(async (req, res) => {
  const { node_id: nodeId, extension_version: extensionVersion, tasks_completed: tasksCompleted } =
    req.body || {};
  if (!nodeId) return res.status(400).json({ ok: false, error: 'node_id required' });
  const node = await helixNodes.heartbeatNode(nodeId, { extensionVersion, tasksCompleted });
  if (!node) return res.status(404).json({ ok: false, error: 'node not found' });
  res.json({ ok: true, node });
}));

router.get('/status/:nodeId', asyncRoute(async (req, res) => {
  const node = await helixNodes.getNodeStatus(req.params.nodeId);
  if (node.error) return res.status(404).json({ ok: false, error: node.error });
  res.json({ ok: true, node });
}));

router.get('/leaderboard', asyncRoute(async (_req, res) => {
  res.json({ ok: true, leaderboard: await helixNodes.getLeaderboard() });
}));

router.post('/actions', asyncRoute(async (req, res) => {
  const { node_id: nodeId, action } = req.body || {};
  if (!nodeId || !action) {
    return res.status(400).json({ ok: false, error: 'node_id and action required' });
  }
  const node = await helixNodes.recordAction(nodeId, action);
  res.json({ ok: true, node, action });
}));

router.get('/lottery/current', asyncRoute(async (_req, res) => {
  res.json({ ok: true, ...(await helixNodes.getLottery()) });
}));

router.post('/lottery/draw', asyncRoute(async (req, res) => {
  if (process.env.HELIX_NODES_DRY_RUN !== '0' && req.query.confirm !== '1') {
    return res.status(403).json({
      ok: false,
      error: 'Set HELIX_NODES_DRY_RUN=0 and ?confirm=1 for live lottery draw',
    });
  }
  res.json({ ok: true, ...(await helixNodes.drawLottery()) });
}));

export default router;
