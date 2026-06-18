import test from 'node:test';
import assert from 'node:assert/strict';
import { ingestMiningTelemetry, getMiningSummary } from '../adapters/mining.js';

test('ingestMiningTelemetry accepts openclaw pulse', () => {
  const result = ingestMiningTelemetry({
    source: 'openclaw-mining',
    instanceId: 'openclaw-test-1',
    provider: 'vast',
    cpuCoin: 'xmr',
    gpuCoin: 'kaspa',
    vramUsedGb: 12.5,
    tempC: 72,
    gpuUtilPct: 88,
    creditBurnMode: true,
  });
  assert.equal(result.accepted, true);
  assert.equal(result.pillar5.integrityConfirmed, true);
  assert.ok(result.pillar7.evolution);
});

test('getMiningSummary reports active instances', () => {
  ingestMiningTelemetry({ instanceId: 'openclaw-test-2', provider: 'akash', tempC: 65 });
  const summary = getMiningSummary();
  assert.equal(summary.service, 'openclaw-mining');
  assert.ok(summary.activeInstances >= 1);
});
