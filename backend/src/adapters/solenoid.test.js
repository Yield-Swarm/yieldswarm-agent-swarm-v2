import assert from 'node:assert/strict';
import test from 'node:test';

import {
  applyThrottle,
  getSolenoidStatus,
  ingestTelemetryPulse,
  pruneContext,
  runAxisMatrix,
  shiftSolenoidMode,
} from '../adapters/solenoid.js';

test('getSolenoidStatus returns quadrilateral axis snapshot', () => {
  const status = getSolenoidStatus();
  assert.equal(status.pillars, 14);
  assert.ok(status.stateChainHash);
});

test('ingestTelemetryPulse verifies pillar context', () => {
  const result = ingestTelemetryPulse({
    pillarId: '3',
    name: '03_zk_mayhem_core',
    metrics: { gpu_temperature: 78, vram_used_bytes: 24_000_000_000 },
  });
  assert.equal(result.status, 'SUCCESS');
  assert.ok(result.stateAnchor);
});

test('applyThrottle records thermal shed state', () => {
  const result = applyThrottle({ status: 'THERMAL_LIMIT_EXCEEDED', temp: 84 });
  assert.equal(result.accepted, true);
  assert.equal(result.throttled, true);
});

test('pruneContext increments prune counter', () => {
  const before = getSolenoidStatus().context.pruneCount;
  const result = pruneContext({ force: true });
  assert.equal(result.accepted, true);
  assert.equal(getSolenoidStatus().context.pruneCount, before + 1);
});

test('runAxisMatrix executes 14-pillar lane matrix', async () => {
  const result = await runAxisMatrix({ tenantId: 'test-tenant', locale: 'en' });
  assert.equal(result.layer, 'PDs1_QUADRILATERAL_AXIS_COMPLETE');
  assert.equal(result.matrix.length, 14);
});

test('shiftSolenoidMode elevates to pentagram and elevators', () => {
  const pentagram = shiftSolenoidMode('PENTAGRAM');
  assert.equal(pentagram.success, true);
  assert.equal(pentagram.mode, 'PENTAGRAM');
  const elevators = shiftSolenoidMode('14X_ELEVATORS');
  assert.equal(elevators.success, true);
  assert.equal(elevators.mode, '14X_ELEVATORS');
});
