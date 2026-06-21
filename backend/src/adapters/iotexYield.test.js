import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  receiveCrossChainYield,
  listIotexInflowEvents,
  clearIotexInflowEvents,
  normalizeYieldDestination,
} from './iotexYield.js';

describe('iotexYield', () => {
  beforeEach(() => clearIotexInflowEvents());

  it('normalizes public destination aliases', () => {
    assert.equal(normalizeYieldDestination('iotex_treasury'), 'iotex');
    assert.equal(normalizeYieldDestination('btc_via_iopay'), 'btc_iopay');
    assert.equal(normalizeYieldDestination('iotex'), 'iotex');
  });

  it('routes to IoTeX treasury', () => {
    const r = receiveCrossChainYield({
      agentId: 'agent-1',
      amount: '100',
      destination: 'iotex',
      sourceChain: 'solana',
    });
    assert.equal(r.ok, true);
    assert.equal(r.routing.destination, 'iotex');
    assert.equal(r.routing.address, '0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567');
    assert.equal(r.event.type, 'IotexYieldInflow');
  });

  it('routes to BTC via IOPAY', () => {
    const r = receiveCrossChainYield({
      agentId: 'agent-2',
      amount: '0.01',
      currency: 'BTC',
      destination: 'btc_iopay',
      sourceChain: 'base',
    });
    assert.equal(r.routing.destination, 'btc_iopay');
    assert.equal(r.routing.address, 'bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8');
  });

  it('emits inflow events', () => {
    receiveCrossChainYield({
      agentId: 'agent-3',
      amount: '1',
      destination: 'iotex',
      sourceChain: 'ethereum',
    });
    assert.equal(listIotexInflowEvents().length, 1);
  });

  it('requires agentId and positive amount', () => {
    assert.throws(
      () => receiveCrossChainYield({ amount: '1', destination: 'iotex' }),
      /agentId/,
    );
    assert.throws(
      () => receiveCrossChainYield({ agentId: 'a', amount: '0', destination: 'iotex' }),
      /amount/,
    );
  });
});
