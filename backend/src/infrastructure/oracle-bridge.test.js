import test from 'node:test';
import assert from 'node:assert/strict';
import { YieldSwarmOracleBridge } from '../infrastructure/oracle-bridge.js';

test('YieldSwarmOracleBridge.encodeMutationResponse returns 0x-prefixed bytes', () => {
  const encoded = YieldSwarmOracleBridge.encodeMutationResponse({
    tokenId: 42,
    tier: 3,
    winRateBps: 7500,
    uri: 'https://example.com/meta/42',
  });
  assert.ok(encoded.startsWith('0x'));
  assert.ok(encoded.length > 10);
});

test('YieldSwarmOracleBridge requires provider and contract', () => {
  assert.throws(
    () => new YieldSwarmOracleBridge('', '0xabc'),
    /providerUrl and contractAddress/,
  );
});

test('YieldSwarmOracleBridge reports unconfigured without private key', () => {
  const bridge = new YieldSwarmOracleBridge('http://localhost:8545', '0x' + 'ab'.repeat(20));
  assert.equal(bridge.configured, false);
});
