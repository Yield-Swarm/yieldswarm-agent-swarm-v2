import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TtlCache } from './cache.js';

test('TtlCache serves cached value within TTL and refreshes after expiry', async () => {
  const cache = new TtlCache(50);
  let calls = 0;
  const producer = async () => {
    calls += 1;
    return calls;
  };

  const a = await cache.get('k', producer);
  const b = await cache.get('k', producer);
  assert.equal(a, 1);
  assert.equal(b, 1, 'second call within TTL returns cached value');
  assert.equal(calls, 1, 'producer ran once');

  await new Promise((r) => setTimeout(r, 60));
  const c = await cache.get('k', producer);
  assert.equal(c, 2, 'value refreshed after TTL expiry');
  assert.equal(calls, 2);
});

test('TtlCache de-duplicates concurrent producers (single-flight)', async () => {
  const cache = new TtlCache(1000);
  let calls = 0;
  const producer = async () => {
    calls += 1;
    await new Promise((r) => setTimeout(r, 20));
    return 'value';
  };

  const [a, b, c] = await Promise.all([
    cache.get('x', producer),
    cache.get('x', producer),
    cache.get('x', producer),
  ]);

  assert.equal(a, 'value');
  assert.equal(b, 'value');
  assert.equal(c, 'value');
  assert.equal(calls, 1, 'concurrent callers share one producer invocation');
});
