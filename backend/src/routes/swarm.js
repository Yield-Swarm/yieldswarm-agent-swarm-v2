/**
 * Swarm spawn API — encrypted IDs, telemetry, multi-mine, game mesh.
 */

import { Router } from 'express';
import { mintPowId, mintPosId, mintPowUiId, resolveEncryptedId, isEncryptedSwarmId } from '../../../lib/encrypted-swarm-id.mjs';
import { ingestPhysicalTelemetry, getPhysicalTelemetryStatus } from '../../../services/telemetry/physical-core.mjs';
import { onboardAgent } from '../../../services/game/cosmic-onboarding.mjs';
import { createMeshPool } from '../../../services/mesh/agent-worker-pool.mjs';

const router = Router();
const mesh = createMeshPool({ maxAgents: Number(process.env.MESH_AGENT_COUNT || 256) });

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'swarm failure' });
    });
  };
}

router.get('/health', (_req, res) => {
  res.json({ service: 'swarm-spawn', layers: 35, ethical_scope: 'paid-and-owned-hardware-only' });
});

router.post('/encrypted-id/mint', asyncRoute(async (req, res) => {
  const { type, rawId, meta } = req.body || {};
  if (!rawId) return res.status(400).json({ error: 'rawId required' });
  const mint = type === 'pos' ? mintPosId : type === 'powui' ? mintPowUiId : mintPowId;
  res.json({ encrypted_id: mint(rawId, meta || {}), type: type || 'pow' });
}));

router.post('/encrypted-id/resolve', asyncRoute(async (req, res) => {
  const { token } = req.body || {};
  if (!isEncryptedSwarmId(token)) return res.status(400).json({ error: 'invalid encrypted swarm id' });
  const resolved = resolveEncryptedId(token);
  res.json({ ok: true, type: resolved.type, minted_at: resolved.mintedAt });
}));

router.post('/telemetry/physical', asyncRoute(async (req, res) => {
  const data = await ingestPhysicalTelemetry(req.body || {});
  res.status(201).json(data);
}));

router.get('/telemetry/physical', asyncRoute(async (_req, res) => {
  res.json(await getPhysicalTelemetryStatus());
}));

router.post('/onboarding/cosmic', asyncRoute(async (req, res) => {
  const data = await onboardAgent(req.body || {});
  res.status(201).json(data);
}));

router.post('/mesh/tick', asyncRoute(async (req, res) => {
  const size = Number(req.body?.batch || 32);
  res.json(await mesh.tickBatch(size));
}));

export default router;
