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
      engine.ingest({ vramUsedGb: 12 + i * 0.1, tempC: 65 + (i % 5), timestamp: 1_700_000_000_000 + i });
    }
    expect(engine.getWindow().length).toBe(64);
    const v = engine.verifyChain();
    expect(v.valid).toBe(true);
    expect(engine.exportProofSeed().blockCount).toBe(64);
  });

  it("generates ZK seed with proof (dev mode)", async () => {
    const engine = new HardenedAuditEngine();
    engine.ingest({ vramUsedGb: 14, tempC: 68 });
    const seed = await engine.generateSeedWithProof();
    expect(seed.commitment).toBeDefined();
    expect(seed.publicSignals.length).toBe(3);
    expect(seed.entropyQuality).toBeGreaterThan(0);
    expect(seed.pillar).toBe("A1-Ancestral");
  });
});

describe("telemetry-validation-bridge", () => {
  it("pulses GPU telemetry into HardenedAuditEngine with pillar envelope", async () => {
    const { pulseGpuTelemetry } = await import("./telemetry-validation-bridge.js");
    const r = pulseGpuTelemetry({
      pillarId: "04_akash_gpu_workers",
      vramUsedGb: 8.5,
      tempC: 62,
      utilizationPct: 45,
      gpuId: "nvidia-p40",
    });
    expect(r.pillarId).toBe("04_akash_gpu_workers");
    expect(r.status).toBe("green");
    expect(r.chainVerify.valid).toBe(true);
    expect(r.auditBlock.blockVerificationHash).toHaveLength(64);
  });

  it("flags mayhem breach above VRAM and thermal ceiling", async () => {
    const { pulseGpuTelemetry } = await import("./telemetry-validation-bridge.js");
    const r = pulseGpuTelemetry({ vramUsedGb: 30, tempC: 85 });
    expect(r.status).toBe("mayhem_breach");
  });
});

describe("zk-entropy-prover", () => {
  it("sanitizes telemetry within policy bounds", async () => {
    const { sanitizeTelemetry, computeCommitment, generateDevProof, verifyProofLocally } =
      await import("./zk-entropy-prover.js");
    const witness = sanitizeTelemetry({ vramUsedGb: 12, tempC: 70 });
    expect(witness.vramScaled).toBe(12000);
    const commitment = await computeCommitment(witness);
    expect(commitment).toBeTruthy();
    const proof = await generateDevProof({ vramUsedGb: 12, tempC: 70 });
    const v = await verifyProofLocally(proof);
    expect(v.valid).toBe(true);
  });

  it("rejects out-of-policy telemetry", async () => {
    const { sanitizeTelemetry } = await import("./zk-entropy-prover.js");
    expect(() => sanitizeTelemetry({ vramUsedGb: 35, tempC: 70 })).toThrow(/vram/);
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

  it("ranks higher with entropy quality bonus", () => {
    const opt = new SovereignOptimizer();
    const low = opt.rankWithEntropy({ entropyQuality: 0.1 });
    const high = opt.rankWithEntropy({ entropyQuality: 0.95 });
    expect(high[0].score).toBeGreaterThan(low[0].score);
  });
});
