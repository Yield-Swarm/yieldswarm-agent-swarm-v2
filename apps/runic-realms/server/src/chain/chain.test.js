import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ALCHEMY_CHAINS } from '../config/alchemy-chains.js';
import { buildRpcUrl, listChains, routeComputeJob } from '../chain/alchemyRouter.js';
import { registerPlotraDeity } from '../agents/plotraAgents.js';

describe('alchemy router', () => {
  it('lists mainnet chains', () => {
    const chains = listChains(false);
    assert.ok(chains.length >= 10);
    assert.ok(chains.every((c) => !c.testnet));
  });

  it('builds RPC URL when key set', () => {
    const prev = process.env.ALCHEMY_API_KEY;
    process.env.ALCHEMY_API_KEY = 'test-key';
    const url = buildRpcUrl('eth-mainnet');
    assert.match(url, /eth-mainnet\.g\.alchemy\.com\/v2\/test-key/);
    process.env.ALCHEMY_API_KEY = prev;
  });

  it('routes compute job in simulation without key', async () => {
    const prev = process.env.ALCHEMY_API_KEY;
    delete process.env.ALCHEMY_API_KEY;
    const route = await routeComputeJob({ id: 'job_test_1' });
    assert.equal(route.simulated, true);
    assert.ok(ALCHEMY_CHAINS.some((c) => c.id === route.chain));
    process.env.ALCHEMY_API_KEY = prev;
  });
});

describe('plotra agents', () => {
  it('registers simulated deity agent', async () => {
    process.env.PLOTRA_SIMULATE = '1';
    const record = await registerPlotraDeity({
      telegramId: 'test_plotra_1',
      displayName: 'Baris',
      classId: 'runeblade',
    });
    assert.ok(record.agent_id);
    assert.ok(record.view_url.includes('plotra.xyz'));
    delete process.env.PLOTRA_SIMULATE;
  });
});
