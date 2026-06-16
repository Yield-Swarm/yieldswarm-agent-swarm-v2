import test from 'node:test';
import assert from 'node:assert/strict';
import { DydxExecutionBridge } from '../infrastructure/dydx-bridge.js';

test('DydxExecutionBridge builds ws endpoint from indexer URL', () => {
  const bridge = new DydxExecutionBridge('https://indexer.dydx.trade/v4', 'dydx1abc');
  assert.equal(bridge.wsEndpoint, 'wss://indexer.dydx.trade/v4/ws');
  assert.equal(bridge.subaccountId, 'dydx1abc');
});

test('fetchActivePositions returns empty when subaccount missing', async () => {
  const bridge = new DydxExecutionBridge('https://indexer.dydx.trade/v4', '');
  const result = await bridge.fetchActivePositions();
  assert.equal(result.live, false);
  assert.deepEqual(result.positions, []);
});
