import assert from 'node:assert/strict';
import test from 'node:test';

import { toAkashTelemetryPayload, toOdysseusTelemetryPayload } from './telemetryFormat.js';
import { getVaultTelemetry } from './vault.js';

test('toAkashTelemetryPayload maps worker snapshot for static Arena', () => {
  const payload = toAkashTelemetryPayload({
    live: true,
    source: 'akash-console',
    workers: [
      { id: 'gpu-1', state: 'active', gpu: 'RTX3090', cpuUtil: 0.5, memUtil: 0.4, hashrateMhs: 90, kind: 'gpu-miner' },
    ],
  });
  assert.equal(payload.workers.length, 1);
  assert.equal(payload.workers[0].gpuCount, 1);
  assert.equal(payload.status, 'active');
});

test('toOdysseusTelemetryPayload maps agent snapshot for static Arena', () => {
  const payload = toOdysseusTelemetryPayload({
    live: false,
    source: 'fallback',
    payload: {
      agents: [{ id: 'a1', status: 'healthy', activeResearchRuns: 2 }],
      memory: { items: 10, vectors: 40 },
      queueDepth: 1,
    },
  });
  assert.equal(payload.agents.length, 1);
  assert.equal(payload.memory.items, 10);
  assert.equal(payload.alerts.length, 1);
});

test('getVaultTelemetry reads sovereign state from dashboard/state.json', async () => {
  const vault = await getVaultTelemetry();
  assert.ok((vault.vault_target_usd ?? vault.vaultTargetUsd) >= 5_000_000);
  assert.ok(typeof (vault.progress) === 'number');
});
