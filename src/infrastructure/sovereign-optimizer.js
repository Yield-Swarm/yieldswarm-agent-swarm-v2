/**
 * Team 4 — sovereign credit optimizer for $5,408 free cloud credit pool.
 *
 * Tracks, hedges, and arbitrages credits across Akash, Vast.io, GCP, Azure, AWS,
 * and Alibaba Cloud based on latency vs compute tier cost.
 */

/** @typedef {'akash'|'vast'|'gcp'|'azure'|'aws'|'alibaba'} ProviderId */

/** @typedef {object} ProviderProfile
 * @property {ProviderId} id
 * @property {number} creditsUsd remaining credits
 * @property {number} costPerGpuHourUsd
 * @property {number} latencyMs p50 to target region
 * @property {string} gpuTier e.g. RTX_5090, H100, A100
 * @property {boolean} available
 */

export const DEFAULT_CREDIT_POOL_USD = 5_408;

/** @type {ProviderProfile[]} */
export const DEFAULT_PROVIDERS = [
  { id: "akash", creditsUsd: 1_200, costPerGpuHourUsd: 0.42, latencyMs: 85, gpuTier: "RTX_3090", available: true },
  { id: "vast", creditsUsd: 800, costPerGpuHourUsd: 0.38, latencyMs: 95, gpuTier: "RTX_4090", available: true },
  { id: "gcp", creditsUsd: 1_500, costPerGpuHourUsd: 2.10, latencyMs: 45, gpuTier: "A100", available: true },
  { id: "azure", creditsUsd: 1_000, costPerGpuHourUsd: 1.95, latencyMs: 50, gpuTier: "A100", available: true },
  { id: "aws", creditsUsd: 708, costPerGpuHourUsd: 2.25, latencyMs: 55, gpuTier: "A100", available: true },
  { id: "alibaba", creditsUsd: 200, costPerGpuHourUsd: 1.60, latencyMs: 180, gpuTier: "A10", available: true },
];

  /**
   * Score provider for a workload profile (higher = better).
   * @param {ProviderProfile} p
   * @param {object} workload
   * @param {number} workload.latencyWeight 0-1
   * @param {number} workload.costWeight 0-1
   * @param {string} [workload.preferredGpu]
   * @param {number} [workload.entropyQuality] 0-1 from ZK entropy engine (U¹ feedback)
   */
export function scoreProvider(p, workload) {
  if (!p.available || p.creditsUsd <= 0) return -Infinity;

  const latencyWeight = workload.latencyWeight ?? 0.4;
  const costWeight = workload.costWeight ?? 0.6;
  const entropyWeight = workload.entropyWeight ?? 0.15;

  const latencyScore = 1 / (1 + p.latencyMs / 100);
  const costScore = 1 / (1 + p.costPerGpuHourUsd);
  const gpuBonus = workload.preferredGpu && p.gpuTier.includes(workload.preferredGpu) ? 0.15 : 0;
  const creditBonus = Math.min(0.2, p.creditsUsd / DEFAULT_CREDIT_POOL_USD);
  const entropyBonus = (workload.entropyQuality ?? 0) * entropyWeight;

  return latencyWeight * latencyScore + costWeight * costScore + gpuBonus + creditBonus + entropyBonus;
}

export class SovereignOptimizer {
  /**
   * @param {ProviderProfile[]} [providers]
   */
  constructor(providers = DEFAULT_PROVIDERS) {
    this.providers = providers.map((p) => ({ ...p }));
    this.allocations = [];
  }

  /** Total remaining credits across providers. */
  totalCredits() {
    return this.providers.reduce((s, p) => s + p.creditsUsd, 0);
  }

  /**
   * Rank providers for a workload.
   * @param {object} workload
   */
  rank(workload = {}) {
    return [...this.providers]
      .map((p) => ({ ...p, score: scoreProvider(p, workload) }))
      .filter((p) => p.score > -Infinity)
      .sort((a, b) => b.score - a.score);
  }

  /**
   * Rank with ZK entropy quality feedback (O¹ + U¹ pillars).
   * @param {object} workload
   * @param {number} [workload.entropyQuality] 0-1
   */
  rankWithEntropy(workload = {}) {
    return this.rank({
      ...workload,
      entropyWeight: workload.entropyWeight ?? 0.2,
    });
  }

  /**
   * Proof-generation speed feedback — deprioritize providers when entropy proofs are slow.
   * @param {number} proofLatencyMs
   * @param {number} entropyQuality
   */
  adjustForProofLatency(proofLatencyMs, entropyQuality = 0.5) {
    const penalty = Math.min(0.3, proofLatencyMs / 60_000);
    for (const p of this.providers) {
      if (p.id === "akash" || p.id === "vast") {
        p._latencyPenalty = penalty * (1 - entropyQuality);
      }
    }
    return { penalty, entropyQuality };
  }

  /**
   * Allocate GPU hours against the credit pool with hedging (split top-N).
   * @param {object} req
   * @param {number} req.gpuHours
   * @param {number} [req.hedgeProviders=2] split across top N providers
   * @param {object} [req.workload]
   */
  allocate(req) {
    const { gpuHours, hedgeProviders = 2, workload = {} } = req;
    if (gpuHours <= 0) throw new RangeError("gpuHours must be positive");

    const ranked = this.rank(workload);
    if (!ranked.length) throw new Error("no available providers");

    const picks = ranked.slice(0, Math.min(hedgeProviders, ranked.length));
    const share = gpuHours / picks.length;
    const plan = [];

    for (const p of picks) {
      const cost = share * p.costPerGpuHourUsd;
      if (cost > p.creditsUsd) {
        const affordableHours = p.creditsUsd / p.costPerGpuHourUsd;
        plan.push({
          provider: p.id,
          gpuHours: affordableHours,
          costUsd: p.creditsUsd,
          capped: true,
          score: p.score,
        });
        p.creditsUsd = 0;
      } else {
        plan.push({
          provider: p.id,
          gpuHours: share,
          costUsd: cost,
          capped: false,
          score: p.score,
        });
        p.creditsUsd -= cost;
      }
    }

    const entry = {
      requestedGpuHours: gpuHours,
      plan,
      totalCostUsd: plan.reduce((s, r) => s + r.costUsd, 0),
      remainingPoolUsd: this.totalCredits(),
      at: new Date().toISOString(),
    };

    this.allocations.push(entry);
    return entry;
  }

  /**
   * Arbitrage signal: cheapest provider with acceptable latency.
   * @param {number} maxLatencyMs
   */
  arbitrageOpportunity(maxLatencyMs = 120) {
    const eligible = this.providers.filter((p) => p.available && p.creditsUsd > 0 && p.latencyMs <= maxLatencyMs);
    if (!eligible.length) return null;
    return eligible.reduce((best, p) => (p.costPerGpuHourUsd < best.costPerGpuHourUsd ? p : best));
  }

  snapshot() {
    return {
      poolUsd: this.totalCredits(),
      providers: this.providers,
      allocationCount: this.allocations.length,
      lastAllocation: this.allocations[this.allocations.length - 1] ?? null,
    };
  }
}

export const sovereignOptimizer = new SovereignOptimizer();

export default sovereignOptimizer;
