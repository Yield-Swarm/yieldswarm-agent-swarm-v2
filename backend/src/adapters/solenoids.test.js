/**
 * Solenoid architecture tests — Nexus, Helix treasury, Shadow Arena.
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getNexusOrchestrator } from '../../../solenoids/nexus/index.js';
import { CLOUD_PROVIDERS } from '../../../solenoids/nexus/constants.js';
import { routeYieldToMiningRoots, submitZkSwarmBatch } from './helixTreasury.js';
import {
  fundArenaPool,
  getArenaStatus,
  registerCompetitor,
  submitArenaScore,
} from './shadowArena.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RUN_DIR = path.join(__dirname, '..', '..', '.run');
const NEXUS_STATE = path.join(RUN_DIR, 'nexus-registry.json');
const SHADOW_STATE = path.join(RUN_DIR, 'shadow-arena.json');

describe('Nexus Chain orchestrator', () => {
  before(async () => {
    await fs.mkdir(RUN_DIR, { recursive: true });
    try { await fs.unlink(NEXUS_STATE); } catch { /* */ }
  });

  it('initializes registry with three solenoids', async () => {
    const nexus = getNexusOrchestrator();
    const status = await nexus.init();
    assert.equal(status.solenoid, 'nexus');
    assert.equal(status.registry.solenoids.length, 3);
    assert.equal(status.registry.maxAgents, 521);
  });

  it('registers agents up to cap', async () => {
    const nexus = getNexusOrchestrator();
    const agent = await nexus.registerAgent({
      id: `test-agent-${Date.now()}`,
      pubkey: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      solenoidId: 'helix',
    });
    assert.ok(agent.id.startsWith('test-agent-'));
  });

  it('allocates multi-cloud resources', async () => {
    const nexus = getNexusOrchestrator();
    const alloc = await nexus.allocateResource({
      workloadId: 'wk-test-1',
      provider: CLOUD_PROVIDERS.AZURE,
      gpu: 1,
      cpu: 4,
      memoryGb: 16,
    });
    assert.equal(alloc.provider, 'azure');
    assert.equal(alloc.status, 'active');
  });
});

describe('Helix Reverberator treasury', () => {
  it('routes yield to all mining roots including iotex', async () => {
    const receipt = await routeYieldToMiningRoots({
      grossLamports: 1_000_000,
      dryRun: true,
    });
    assert.equal(receipt.dryRun, true);
    const iotex = receipt.routes.find((r) => r.rootKey === 'iotex');
    assert.ok(iotex);
    assert.ok(iotex.address.startsWith('0x'));
    assert.equal(receipt.routes.length, 9);
  });

  it('accepts ZK-Swarm batch', async () => {
    const batch = await submitZkSwarmBatch({
      proofs: [{ proof: '0xabc', publicInputsHash: '0xdef' }],
      mutationRoot: '0x123',
    });
    assert.ok(batch.batchId);
    assert.equal(batch.count, 1);
  });
});

describe('Shadow Chain Arena', () => {
  before(async () => {
    try { await fs.unlink(SHADOW_STATE); } catch { /* */ }
  });

  it('reports arena status', async () => {
    const status = await getArenaStatus();
    assert.equal(status.solenoid, 'shadow');
    assert.equal(status.owner, 'kyle');
  });

  it('registers competitor with swarm_ops gate', async () => {
    const id = `arena-agent-${Date.now()}`;
    const competitor = await registerCompetitor({
      agentId: id,
      pubkey: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      swarmRegistered: true,
    });
    assert.equal(competitor.agentId, id);
  });

  it('updates score and reputation', async () => {
    const id = `arena-score-${Date.now()}`;
    await registerCompetitor({
      agentId: id,
      pubkey: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      swarmRegistered: true,
    });
    const result = await submitArenaScore({
      agentId: id,
      score: 1000,
      won: true,
    });
    assert.ok(result.reputation > 0);
  });

  it('funds reward pool', async () => {
    const pool = await fundArenaPool(5_000_000);
    assert.ok(pool.rewardPoolLamports >= 5_000_000);
  });
});
