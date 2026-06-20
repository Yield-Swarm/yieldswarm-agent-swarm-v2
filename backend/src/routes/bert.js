/**
 * BERT workload deployment API — pillar 04_akash_gpu_workers.
 */

import { Router } from 'express';
import {
  getBertWorkerStatus,
  predictMasked,
  routeWorkloadBatch,
  TASK_TYPES,
} from '../adapters/akashBert.js';

const router = Router();

function asyncRoute(fn) {
  return (req, res) => {
    Promise.resolve(fn(req, res)).catch((err) => {
      res.status(502).json({ error: err.message || 'bert workload failure' });
    });
  };
}

router.get('/status', asyncRoute(async (_req, res) => {
  res.json(getBertWorkerStatus());
}));

router.get('/tasks', asyncRoute(async (_req, res) => {
  res.json({ tasks: TASK_TYPES, endpoint: '/predict' });
}));

/** POST /api/bert/predict — single RAG/memory/coordination task */
router.post('/predict', asyncRoute(async (req, res) => {
  const body = req.body || {};
  const result = await predictMasked({
    task: body.task || 'rag_memory',
    text: body.text,
    tenantId: body.tenantId || body.tenant_id,
    pillarId: body.pillarId || '04_akash_gpu_workers',
  });
  res.json(result);
}));

/** POST /api/bert/batch — swarm workload batch */
router.post('/batch', asyncRoute(async (req, res) => {
  const body = req.body || {};
  const tasks = body.tasks || body.workloads || [];
  if (!Array.isArray(tasks) || tasks.length === 0) {
    res.status(400).json({ error: 'tasks array required' });
    return;
  }
  const result = await routeWorkloadBatch({
    tasks,
    tenantId: body.tenantId || body.tenant_id,
    pillarId: body.pillarId,
  });
  res.json(result);
}));

export default router;
