/**
 * O¹ Oscillator — rhythmic ZK proof generation aligned with mutation cycles.
 *
 * Schedules proof generation based on cluster load and entropy quality feedback.
 * Usage: node src/automation/zk-mutation-scheduler.js
 */

import { HardenedAuditEngine } from "../infrastructure/entropy-core.js";
import { entropyQualityScore } from "../infrastructure/zk-entropy-prover.js";
import { sovereignOptimizer } from "../infrastructure/sovereign-optimizer.js";

const MUTATION_INTERVAL_MS = Number(process.env.ZK_MUTATION_INTERVAL_MS || 7 * 24 * 60 * 60 * 1000);
const MIN_QUALITY = Number(process.env.ZK_MIN_ENTROPY_QUALITY || 0.5);
const WEBHOOK_URL = process.env.MUTATION_WEBHOOK_URL || "";

/**
 * Non-linear schedule: shorter interval when entropy quality is high.
 * @param {number} quality 0–1
 * @param {number} clusterLoad 0–1
 */
export function computeNextIntervalMs(quality, clusterLoad = 0) {
  const qualityFactor = 0.5 + quality; // 0.5–1.5
  const loadFactor = 1 + clusterLoad * 0.5; // 1–1.5
  return Math.round(MUTATION_INTERVAL_MS / qualityFactor / loadFactor);
}

/**
 * @param {HardenedAuditEngine} engine
 * @param {object} telemetry
 */
export async function runMutationCycle(engine, telemetry) {
  engine.ingest(telemetry);
  const quality = engine.entropyQuality();

  if (quality < MIN_QUALITY) {
    return { skipped: true, reason: "entropy quality below threshold", quality };
  }

  const seedProof = await engine.generateSeedWithProof();
  const routing = sovereignOptimizer.rankWithEntropy({
    latencyWeight: 0.35,
    costWeight: 0.45,
    entropyQuality: quality,
  });

  if (WEBHOOK_URL) {
    await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        type: "zk_mutation_cycle",
        seedProof,
        routingTop: routing[0]?.id ?? null,
        quality,
      }),
    }).catch((err) => console.warn("[zk-scheduler] webhook failed:", err.message));
  }

  return { skipped: false, quality, commitment: seedProof.commitment, routing };
}

async function main() {
  const engine = new HardenedAuditEngine();
  let clusterLoad = 0;

  const tick = async () => {
    const sample = {
      vramUsedGb: 12 + Math.random() * 8,
      tempC: 62 + Math.random() * 12,
      utilizationPct: 40 + Math.random() * 40,
      timestamp: Date.now(),
    };

    const result = await runMutationCycle(engine, sample);
    const quality = engine.entropyQuality();
    const nextMs = computeNextIntervalMs(quality, clusterLoad);
    console.log(`[zk-scheduler] cycle complete`, { ...result, nextMs, qualityScore: entropyQualityScore(sample) });
    clusterLoad = Math.min(1, clusterLoad + (result.skipped ? 0.1 : -0.05));
    setTimeout(tick, nextMs);
  };

  console.log("[zk-scheduler] starting O¹ oscillator loop");
  await tick();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    console.error("[zk-scheduler] fatal:", err);
    process.exit(1);
  });
}

export default { runMutationCycle, computeNextIntervalMs };
