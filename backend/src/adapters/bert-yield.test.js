import assert from 'node:assert/strict';
import test from 'node:test';

import { getBertWorkerStatus, TASK_TYPES } from '../adapters/akashBert.js';
import { getGpuCreditYieldDashboard } from '../adapters/gpuCreditYield.js';

test('getBertWorkerStatus exposes pillar 04 endpoints', () => {
  const prev = process.env.AKASH_BERT_INGRESS_URL;
  process.env.AKASH_BERT_INGRESS_URL = 'https://bert.example.test';
  process.env.AKASH_BERT_HOURLY_COST_USD = '0.17';
  const status = getBertWorkerStatus();
  assert.equal(status.pillarId, '04_akash_gpu_workers');
  assert.equal(status.hourlyCostUsd, 0.17);
  assert.ok(TASK_TYPES.includes('rag_memory'));
  assert.equal(status.endpoint, '/predict');
  process.env.AKASH_BERT_INGRESS_URL = prev;
});

test('getGpuCreditYieldDashboard wires BERT hourly to treasury_yield', () => {
  process.env.AKASH_BERT_HOURLY_COST_USD = '0.17';
  process.env.AKASH_BERT_INGRESS_URL = 'https://bert.example.test';
  const dash = getGpuCreditYieldDashboard();
  assert.equal(dash.pillar, '13_treasury_yield');
  assert.ok(dash.workers.length >= 1);
  const bert = dash.workers.find((w) => w.worker_id === 'akash-bert-p40');
  assert.ok(bert);
  assert.equal(bert.hourly_cost_usd, 0.17);
  assert.equal(bert.daily_burn_usd, Number((0.17 * 24).toFixed(4)));
  assert.equal(bert.treasury_yield_pillar, '13_treasury_yield');
  assert.ok(Array.isArray(bert.great_delta_split_daily));
});
