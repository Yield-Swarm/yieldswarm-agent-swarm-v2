import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { ZKMLReputationEngine } = require('../../../src/zkml-arena/reputation-engine.js');

describe('arena-zkml routes (engine smoke)', () => {
  it('computeAndProve returns proofValid for valid battle', async () => {
    const engine = new ZKMLReputationEngine();
    const result = await engine.computeAndProve(
      { winRate: 7500, consistency: 7200, stakeWeight: 6000 },
      'did:ys:backend-test',
      { battleId: 'bt-1' },
    );
    assert.equal(result.proofValid, true);
    assert.ok(result.score > 0);
  });
});
