import { describe, it, expect } from "vitest";
import {
  hashTenant,
  sanitizeContent,
  sanitizeMessages,
  validateTenant,
  OdysseusRouter,
} from "./odysseus-router.js";
import { HardenedAuditEngine } from "./entropy-core.js";
import { validateOrderRisk, limitsForTier } from "./dydx-bridge.js";
import { SovereignOptimizer } from "./sovereign-optimizer.js";

describe("odysseus-router", () => {
  it("hashes tenants deterministically", () => {
    const a = hashTenant("tenant-alpha-001");
    const b = hashTenant("tenant-alpha-001");
    expect(a).toBe(b);
    expect(a).toHaveLength(64);
  });

  it("rejects cross-tenant hash mismatch", () => {
    expect(() =>
      validateTenant({ tenantId: "tenant-alpha-001", authTenantHash: "deadbeef".repeat(8) }),
    ).toThrow(/zero-trust/);
  });

  it("routes messages into isolated contexts", () => {
    const router = new OdysseusRouter();
    const r = router.route({
      tenantId: "tenant-alpha-001",
      messages: [{ role: "user", content: "hello helix" }],
    });
    expect(r.messages.length).toBe(1);
    expect(r.tenantHash).toBe(hashTenant("tenant-alpha-001"));
  });

  it("sanitizes control characters", () => {
    expect(sanitizeContent("ok\u0000bad")).toBe("okbad");
  });
});

describe("entropy-core", () => {
  it("builds verifiable 64-block window", () => {
    const engine = new HardenedAuditEngine();
    for (let i = 0; i < 70; i++) {
      engine.ingest({ vramUsedGb: 12 + i * 0.1, tempC: 65 + (i % 5) });
    }
    expect(engine.getWindow().length).toBe(64);
    const v = engine.verifyChain();
    expect(v.valid).toBe(true);
    expect(engine.exportProofSeed().blockCount).toBe(64);
  });
});

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
});
