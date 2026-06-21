import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { quoteHelixSettlement, bridgeStatePda, CHAIN_IDS } from './helixBridge.js';

describe('helixBridge adapter', () => {
  it('quotes dry-run settlement without agent', async () => {
    const quote = await quoteHelixSettlement({ amount: 1_000_000 });
    assert.equal(typeof quote.dryRun, 'boolean');
    assert.equal(typeof quote.bridgePda, 'string');
    assert.equal(quote.originChainId, CHAIN_IDS.HELIX);
  });

  it('derives stable bridge state PDA', () => {
    const [a] = bridgeStatePda();
    const [b] = bridgeStatePda();
    assert.equal(a.toBase58(), b.toBase58());
  });
});
