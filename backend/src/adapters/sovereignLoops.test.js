/**
 * Sovereign Loop Engine tests
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);

const {
  SovereignLoopManager,
  assertSovereignCredentials,
  LOOP_STATES,
} = require(path.join(repoRoot, 'src', 'infrastructure', 'sovereign-loop', 'SovereignLoopManager.js'));

describe('SovereignLoopManager', () => {
  const prevVault = process.env.VAULT_SECRET_TOKEN;
  const prevKey = process.env.SOVEREIGN_LOOP_KEY;

  before(() => {
    process.env.VAULT_SECRET_TOKEN = 'test-vault-token';
    process.env.SOVEREIGN_LOOP_KEY = 'test-loop-key';
  });

  after(() => {
    if (prevVault) process.env.VAULT_SECRET_TOKEN = prevVault;
    else delete process.env.VAULT_SECRET_TOKEN;
    if (prevKey) process.env.SOVEREIGN_LOOP_KEY = prevKey;
    else delete process.env.SOVEREIGN_LOOP_KEY;
  });

  it('assertSovereignCredentials passes with env set', () => {
    const creds = assertSovereignCredentials();
    assert.equal(creds.vaultConfigured, true);
  });

  it('evaluateTreasuryHealth detects deficits', () => {
    const mgr = new SovereignLoopManager({ treasuryThresholdUsd: 100_000 });
    mgr.chainBalances = { nexus: 500_000, helix: 50_000, shadow: 80_000, iotex: 90_000 };
    const result = mgr.evaluateTreasuryHealth();
    assert.equal(result.healthy, false);
    assert.ok(result.transfers.length > 0);
  });

  it('checkReplicationStatus triggers above threshold', () => {
    const mgr = new SovereignLoopManager({ replicationThresholdUsd: 100_000 });
    mgr.chainBalances = { nexus: 200_000, helix: 200_000, shadow: 100_000, iotex: 100_000 };
    const rep = mgr.checkReplicationStatus();
    assert.equal(rep.shouldReplicate, true);
    assert.ok(rep.deployment?.replica_id);
  });

  it('triggerPatchCycle heals low penning integrity', () => {
    const mgr = new SovereignLoopManager({ penningTrapMinIntegrity: 0.8 });
    const heal = mgr.triggerPatchCycle({ penning_trap_integrity: 0.5 });
    assert.equal(heal.patched, true);
    assert.ok(heal.actions?.length);
  });

  it('tick runs all three loops', async () => {
    const mgr = new SovereignLoopManager({
      treasuryThresholdUsd: 200_000,
      replicationThresholdUsd: 50_000,
    });
    const snap = await mgr.tick({
      nexus: 100_000,
      helix: 30_000,
      shadow: 40_000,
      iotex: 50_000,
    }, { penning_trap_integrity: 0.6 });
    assert.ok(snap.tickCount >= 1);
    assert.ok(snap.logs.length > 0);
    assert.ok([
      LOOP_STATES.IDLE,
      LOOP_STATES.REBALANCING,
      LOOP_STATES.REPLICATING,
      LOOP_STATES.HEALING,
    ].includes(snap.state));
    assert.ok(snap.metrics?.consolidated_treasury_usd > 0);
  });

  it('forceRebalance applies manual override', async () => {
    const mgr = new SovereignLoopManager({ treasuryThresholdUsd: 100_000 });
    mgr.chainBalances = { nexus: 500_000, helix: 200_000, shadow: 200_000, iotex: 200_000 };
    const snap = await mgr.forceRebalance();
    assert.equal(snap.state, LOOP_STATES.REBALANCING);
    assert.ok(snap.logs.some((l) => l.phase === 'override'));
  });
});
