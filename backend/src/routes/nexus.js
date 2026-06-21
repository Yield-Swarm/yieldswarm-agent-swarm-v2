/**
 * Nexus Chain API — Solenoid 1 orchestration (registry, bus, multicloud).
 */

import { Router } from 'express';
import * as nexus from '../adapters/nexus.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(err.status || 502).json({ error: err.message || 'nexus failure' });
    });
  };
}

router.get('/health', asyncRoute(async (_req, res) => {
  res.json(await nexus.ping());
}));

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(await nexus.getNexusStatus());
}));

router.get('/registry', asyncRoute(async (_req, res) => {
  res.json(await nexus.listSolenoids());
}));

router.post('/agents/register', asyncRoute(async (req, res) => {
  const { agent_id: agentId, solenoid, shard_id: shardId } = req.body || {};
  if (!agentId || !solenoid) {
    return res.status(400).json({ error: 'agent_id and solenoid required' });
  }
  res.status(201).json(await nexus.registerAgent(agentId, solenoid, Number(shardId || 0)));
}));

router.post('/dispatch', asyncRoute(async (req, res) => {
  const { target, topic, payload } = req.body || {};
  if (!target || !topic) {
    return res.status(400).json({ error: 'target and topic required' });
  }
  res.json(await nexus.dispatchMessage(target, topic, payload || {}));
}));

router.post('/multicloud/launch', asyncRoute(async (req, res) => {
  const provider = req.body?.provider || 'akash';
  const workload = req.body?.workload || 'gpu-worker';
  res.json(await nexus.multicloudLaunch(provider, workload));
}));

export default router;
