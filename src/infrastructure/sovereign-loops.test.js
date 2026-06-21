import { describe, expect, it, beforeEach } from 'vitest';
import { SovereignLoopManager, LOOP_STATES } from './SovereignLoopManager.js';

describe('SovereignLoopManager v1.1.0-RU', () => {
  const opts = { skipAuth: true };

  beforeEach(() => {
    process.env.AGENT_COUNT_TOTAL = '10080';
  });

  it('initializes with active loop state and monospace logs', () => {
    const mgr = new SovereignLoopManager(opts);
    const snap = mgr.snapshot();
    expect(snap.currentState).toBe(LOOP_STATES.ACTIVE);
    expect(snap.version).toBe('1.1.0-RU');
    expect(snap.logs[0].message).toMatch(/\[System\s+\]/);
  });

  it('requires vault credentials when skipAuth is false', () => {
    const priorVault = process.env.VAULT_SECRET_TOKEN;
    const priorKey = process.env.SOVEREIGN_LOOP_KEY;
    delete process.env.VAULT_SECRET_TOKEN;
    delete process.env.SOVEREIGN_LOOP_KEY;
    expect(() => new SovereignLoopManager()).toThrow(/configuration error/i);
    process.env.VAULT_SECRET_TOKEN = priorVault;
    process.env.SOVEREIGN_LOOP_KEY = priorKey;
  });

  it('ingests four-chain telemetry', () => {
    const mgr = new SovereignLoopManager(opts);
    mgr.ingestTelemetry({
      sovereign: { net_worth_usd: 1_250_000, treasury_usd: 400_000, counts: { workers: 12, agents: 84 } },
      helix: { treasuryNavUsd: 350_000, engine: { penningTrapIntegrityPct: 99.9991 } },
      iotex: { treasury_usd: 45_000 },
    });
    mgr.runCycle();
    const snap = mgr.snapshot();
    expect(snap.totalTreasury).toBeGreaterThan(0);
    expect(snap.treasuries.iotex).toBeGreaterThan(0);
    expect(snap.penningTrapIntegrity).toBeCloseTo(99.9991, 4);
  });

  it('evaluateTreasuryHealth flags low liquidity', () => {
    const mgr = new SovereignLoopManager(opts);
    mgr.treasuries = { nexus: 500_000, helix: 10_000, shadow: 50_000, iotex: 5_000 };
    const result = mgr.evaluateTreasuryHealth();
    expect(result.healthy).toBe(false);
    expect(result.actions.length).toBeGreaterThan(0);
  });

  it('checkReplicationStatus deploys above threshold', () => {
    const mgr = new SovereignLoopManager({ ...opts, replicationThreshold: 50 });
    mgr.replicationSurplus = 80;
    const result = mgr.checkReplicationStatus();
    expect(result.scale).toBe(true);
    expect(result.deployment?.shardId).toBeDefined();
  });

  it('triggerPatchCycle isolates anomalies', () => {
    const mgr = new SovereignLoopManager(opts);
    mgr.penningTrapIntegrity = 99.97;
    const result = mgr.triggerPatchCycle();
    expect(result.patched).toBe(true);
    expect(mgr.snapshot().currentState).toBe(LOOP_STATES.PATCH);
  });

  it('force rebalance sets economic loop state', () => {
    const mgr = new SovereignLoopManager(opts);
    const snap = mgr.forceRebalance();
    expect(snap.currentState).toBe(LOOP_STATES.REBALANCE);
  });

  it('trigger patch increases penning integrity', () => {
    const mgr = new SovereignLoopManager(opts);
    mgr.penningTrapIntegrity = 99.98;
    const before = mgr.penningTrapIntegrity;
    mgr.triggerPatch();
    expect(mgr.penningTrapIntegrity).toBeGreaterThan(before);
    expect(mgr.snapshot().currentState).toBe(LOOP_STATES.PATCH);
  });
});
