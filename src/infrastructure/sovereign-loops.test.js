import { describe, expect, it } from 'vitest';
import { SovereignLoopManager } from './SovereignLoopManager.js';

describe('SovereignLoopManager', () => {
  it('initializes with nominal state and logs', () => {
    const mgr = new SovereignLoopManager();
    const snap = mgr.snapshot();
    expect(snap.currentState).toBe('Nominal');
    expect(snap.logs.length).toBeGreaterThan(0);
  });

  it('ingests sovereign telemetry and updates treasuries', () => {
    const mgr = new SovereignLoopManager();
    mgr.ingestTelemetry({
      sovereign: { net_worth_usd: 1_250_000, treasury_usd: 400_000, counts: { workers: 12, agents: 84 } },
      helix: { treasuryNavUsd: 350_000, engine: { penningTrapIntegrityPct: 99.9991 } },
    });
    const snap = mgr.snapshot();
    expect(snap.totalTreasury).toBeGreaterThan(0);
    expect(snap.penningTrapIntegrity).toBeCloseTo(99.9991, 4);
  });

  it('force rebalance sets economic loop state', () => {
    const mgr = new SovereignLoopManager();
    const snap = mgr.forceRebalance();
    expect(snap.currentState).toBe('Rebalancing Funds');
    expect(snap.logs[0].message).toMatch(/balanc/i);
  });

  it('trigger patch increases penning integrity', () => {
    const mgr = new SovereignLoopManager();
    mgr.penningTrapIntegrity = 99.98;
    const before = mgr.penningTrapIntegrity;
    mgr.triggerPatch();
    expect(mgr.penningTrapIntegrity).toBeGreaterThan(before);
    expect(mgr.snapshot().currentState).toBe('Executing Self-Heal Patch');
  });
});
