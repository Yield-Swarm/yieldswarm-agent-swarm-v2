import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  BPS_DENOMINATOR,
  GREAT_DELTA_SPLIT_BPS,
  previewSplitBigInt,
  splitAmount,
  validateSplitBps,
  withLegacyAliases,
} from './great-delta-split.js';

test('validateSplitBps accepts canonical 50/30/15/5', () => {
  assert.equal(validateSplitBps(), true);
  assert.equal(
    Object.values(GREAT_DELTA_SPLIT_BPS).reduce((a, b) => a + b, 0),
    BPS_DENOMINATOR,
  );
});

test('previewSplitBigInt matches zero-dust invariant', () => {
  for (const amount of [1n, 99n, 100n, 10_000n, 1_000_000_007n]) {
    const parts = previewSplitBigInt(amount);
    const sum =
      parts.coreTreasury +
      parts.growthTreasury +
      parts.insuranceTreasury +
      parts.opsTreasury;
    assert.equal(sum, amount);
    assert.equal(parts.coreTreasury, (amount * 50n) / 100n);
    assert.equal(parts.growthTreasury, (amount * 30n) / 100n);
    assert.equal(parts.insuranceTreasury, (amount * 15n) / 100n);
  }
});

test('splitAmount allocates remainder to final bucket', () => {
  const rows = splitAmount(100);
  const total = rows.reduce((s, r) => s + r.amount, 0);
  assert.equal(Number(total.toFixed(6)), 100);
  assert.equal(rows[0].bucket, 'coreTreasury');
  assert.equal(rows[0].amount, 50);
});

test('withLegacyAliases maps quadrant-IV names', () => {
  const aliased = withLegacyAliases({ coreTreasury: 50, opsTreasury: 5 });
  assert.equal(aliased.vault, 50);
  assert.equal(aliased.sovereignReserve, 5);
});
