import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeHardenedPoEEmission, streakMultiplier } from './poeMath.js';
import { runConsensusSmokeTest } from './consensusRunner.js';

describe('poeMath', () => {
  it('returns bigint emission within cap', () => {
    const v = computeHardenedPoEEmission(1.5, 8, 120);
    assert.equal(typeof v, 'bigint');
    assert.ok(v > 0n);
    assert.ok(v <= 500_000_000_000n);
  });

  it('clamps delta time to 1–3600', () => {
    const low = computeHardenedPoEEmission(1, 1, 0);
    const high = computeHardenedPoEEmission(1, 1, 99999);
    assert.ok(low > 0n);
    assert.ok(high >= low);
  });

  it('streak multiplier grows with days capped at 6', () => {
    assert.equal(streakMultiplier(0), 1);
    assert.ok(streakMultiplier(6) > streakMultiplier(1));
  });
});

describe('consensusRunner', () => {
  it('passes 100-round smoke test', () => {
    const result = runConsensusSmokeTest(100);
    assert.equal(result.ok, true);
    assert.equal(result.rounds, 100);
    assert.match(result.finalStateRoot, /^[a-f0-9]{64}$/);
  });
});
