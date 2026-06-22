const test = require('node:test');
const assert = require('node:assert/strict');
const { computeRewardAllocation, ATTO_SCALE, MAX_ALLOCATION_PER_TX } = require('./fixedPoint');

test('computeRewardAllocation uses integer nano scale', () => {
  const v = computeRewardAllocation({ baseFactor: 1.5, enemyLevel: 10, deltaTime: 60 });
  assert.equal(typeof v, 'bigint');
  assert.ok(v > 0n);
  assert.ok(v <= MAX_ALLOCATION_PER_TX);
});

test('caps allocation at 500 TON nano units', () => {
  const v = computeRewardAllocation({ baseFactor: 999, enemyLevel: 999, deltaTime: 3600 });
  assert.equal(v, MAX_ALLOCATION_PER_TX);
});

test('ATTO_SCALE matches TVM 10^9', () => {
  assert.equal(ATTO_SCALE, 1_000_000_000n);
});
