import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getTreasurySplits } from './treasury.js';

// With no TREASURY_ADDRESS configured, the adapter returns deterministic
// fallback data without touching the network — so this test is offline-safe.
test('treasury fallback splits sum to the total and percentages to 100', async () => {
  const data = await getTreasurySplits();
  assert.equal(data.live, false);
  assert.equal(data.source, 'fallback');

  const sumSol = data.splits.reduce((acc, s) => acc + s.sol, 0);
  assert.ok(Math.abs(sumSol - data.totalSol) < 0.01, `split SOL (${sumSol}) should sum to total (${data.totalSol})`);

  const sumPct = data.splits.reduce((acc, s) => acc + s.pct, 0);
  assert.ok(Math.abs(sumPct - 100) < 0.01, `split percentages (${sumPct}) should sum to 100`);

  const sumBps = data.splits.reduce((acc, s) => acc + s.bps, 0);
  assert.equal(sumBps, data.totalBps);
});
