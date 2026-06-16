import { describe, it, expect } from "vitest";
import { validateOrderRisk, limitsForTier } from "./dydx-bridge.js";
import { SovereignOptimizer } from "./sovereign-optimizer.js";

/** Quadrilateral / PoW / Rosetta coverage lives in helix-phase1.test.js */

describe("dydx-bridge", () => {
  it("enforces tier-1 notional cap", () => {
    expect(() =>
      validateOrderRisk({ agentTier: 1, notionalUsd: 10_000, leverage: 2, dailyOrdersSoFar: 0 }),
    ).toThrow(/RISK_GATE_REJECTED|exceeds/);
  });

  it("allows tier-5 larger orders", () => {
    const r = validateOrderRisk({ agentTier: 5, notionalUsd: 100_000, leverage: 5, dailyOrdersSoFar: 0 });
    expect(r.approved).toBe(true);
    expect(limitsForTier(5).maxLeverage).toBe(10);
  });
});

describe("sovereign-optimizer", () => {
  it("allocates across hedged providers", () => {
    const opt = new SovereignOptimizer();
    const plan = opt.allocate({ gpuHours: 100, hedgeProviders: 2 });
    expect(plan.plan.length).toBe(2);
    expect(plan.totalCostUsd).toBeGreaterThan(0);
  });

  it("finds arbitrage opportunity", () => {
    const opt = new SovereignOptimizer();
    const opp = opt.arbitrageOpportunity(100);
    expect(opp?.id).toBeDefined();
  });

  it("ranks higher with entropy quality bonus", () => {
    const opt = new SovereignOptimizer();
    const low = opt.rankWithEntropy({ entropyQuality: 0.1 });
    const high = opt.rankWithEntropy({ entropyQuality: 0.95 });
    expect(high[0].score).toBeGreaterThan(low[0].score);
  });
});
