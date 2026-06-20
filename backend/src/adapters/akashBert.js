/**
 * Akash BERT Flask workload router — pillar 04_akash_gpu_workers.
 *
 * Routes agent memory / RAG / coordination tasks to POST /predict (masked-token).
 * Tenant isolation: each request is scoped by tenantHash; no cross-pillar state leak.
 */

import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';
import { requestJson } from '../lib/httpClient.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);
const { logPillarTelemetry } = require(path.join(repoRoot, 'src/infrastructure/pillar-telemetry-log.js'));

export const TASK_TYPES = ['rag_memory', 'agent_coordination', 'yield_inference', 'custom'];

const TASK_MASK_TEMPLATES = {
  rag_memory: (text) => `Agent memory RAG vector: ${text} aligns with [MASK] embedding.`,
  agent_coordination: (text) => `Swarm coordination state for ${text} requires [MASK] vector.`,
  yield_inference: (text) => `Yield optimization for ${text} predicts [MASK] treasury signal.`,
  custom: (text) => text.includes('[MASK]') ? text : `${text} [MASK]`,
};

function baseUrl() {
  return (config.akashBert?.ingressUrl || process.env.AKASH_BERT_INGRESS_URL || '').replace(/\/$/, '');
}

function hashTenant(tenantId) {
  return crypto.createHash('sha256').update(String(tenantId || 'default')).digest('hex');
}

function sanitizeText(input) {
  if (typeof input !== 'string') return '';
  return input.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim().slice(0, 4096);
}

function buildPredictPayload({ task, text, tenantId }) {
  const clean = sanitizeText(text);
  if (!clean) throw new Error('text required');
  const template = TASK_MASK_TEMPLATES[task] || TASK_MASK_TEMPLATES.custom;
  return {
    tenantHash: hashTenant(tenantId),
    task,
    requestText: template(clean),
  };
}

export async function predictMasked({ task = 'rag_memory', text, tenantId, pillarId = '04_akash_gpu_workers' }) {
  const url = baseUrl();
  if (!url) {
    return { live: false, error: 'AKASH_BERT_INGRESS_URL not configured', pillarId };
  }

  const payload = buildPredictPayload({ task, text, tenantId });
  const started = Date.now();

  const response = await requestJson({
    method: 'POST',
    url: `${url}/predict`,
    headers: { 'Content-Type': 'application/json' },
    data: { text: payload.requestText },
    timeout: config.akashBert?.timeoutMs ?? config.upstreamTimeoutMs,
  });

  const latencyMs = Date.now() - started;
  const result = {
    live: true,
    pillarId,
    service: 'bert-flask-inference',
    task,
    tenantHash: payload.tenantHash,
    predicted_token: response?.predicted_token ?? null,
    latencyMs,
    endpoint: url,
    routedAt: new Date().toISOString(),
  };

  logPillarTelemetry(pillarId, 'bert_workload_predict', {
    task,
    tenantHash: payload.tenantHash,
    latencyMs,
  });

  return result;
}

/**
 * Batch route for swarm workloads (light → scale).
 */
export async function routeWorkloadBatch({ tasks = [], tenantId, pillarId }) {
  const results = [];
  for (const item of tasks) {
    try {
      const r = await predictMasked({
        task: item.task || 'rag_memory',
        text: item.text,
        tenantId: item.tenantId || tenantId,
        pillarId,
      });
      results.push({ ok: true, ...r });
    } catch (err) {
      results.push({ ok: false, error: err.message, task: item.task });
    }
  }
  return {
    pillarId: pillarId || '04_akash_gpu_workers',
    batchSize: tasks.length,
    successCount: results.filter((r) => r.ok).length,
    results,
  };
}

export function getBertWorkerStatus() {
  const url = baseUrl();
  return {
    live: Boolean(url),
    pillarId: '04_akash_gpu_workers',
    service: 'bert-flask-inference',
    ingress: url || null,
    dseq: process.env.AKASH_BERT_DSEQ || null,
    gpu: 'nvidia-p40',
    hourlyCostUsd: Number(process.env.AKASH_BERT_HOURLY_COST_USD || 0.17),
    supportedTasks: TASK_TYPES,
    endpoint: '/predict',
    embedAvailable: false,
    note: 'Masked-word /predict only; deploy deploy/akash-bert-flask.sdl.yml for dedicated workers',
  };
}

export default { predictMasked, routeWorkloadBatch, getBertWorkerStatus, TASK_TYPES };
