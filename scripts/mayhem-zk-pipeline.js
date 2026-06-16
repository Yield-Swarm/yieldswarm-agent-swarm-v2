#!/usr/bin/env node
/**
 * Mayhem ZK Pipeline — telemetry → seed → proof → mutation prep (PDs¹ e2e).
 * Usage: node scripts/mayhem-zk-pipeline.js [--dry-run] [--token-id=42]
 */
import { generateSeedWithProof, proposeGenomeDelta, buildRollingWindow } from '../src/infrastructure/entropy-core.js';
import { ZkProofQueue } from '../src/infrastructure/zk-proof-queue.js';
import { hardenedRouteRequest } from '../src/infrastructure/hardened-odysseus-router.js';
import { optimizeTick, applyZkFeedback } from '../src/infrastructure/sovereign-optimizer.js';

const dryRun = process.argv.includes('--dry-run');
const tokenId = process.argv.find((a) => a.startsWith('--token-id='))?.split('=')[1] ?? '42';

const samples = Array.from({ length: 6 }, (_, i) => ({
  gpuTempC: 68 + i * 0.5,
  vramUsedPct: 55 + i,
  vramUsedGb: 18 + i * 0.4,
  powerWatts: 350 + i * 10,
  inferenceTps: 90 + i * 3,
  packetLossPct: 0.3,
  nodeProfile: 'rtx5090',
}));

async function main() {
  const window = buildRollingWindow(samples);
  const telemetry = window.aggregated;

  if (dryRun) {
    console.log(JSON.stringify({ mode: 'dry-run', tokenId, windowSize: window.windowSize }, null, 2));
    return;
  }

  const result = await generateSeedWithProof(telemetry, tokenId, { samples });
  const genome = proposeGenomeDelta({ aggressionBps: 5000, tier: 1 }, result.seed);

  const queue = new ZkProofQueue();
  queue.enqueue({ tokenId, entropyQuality: result.entropyQuality, mutationTier: 1 });
  const batch = queue.nextBatch({ utilization: 0.4, gpuTempC: 72, vramUsedGb: 22 });

  const route = hardenedRouteRequest({
    tokenId,
    callerId: 'sovereign-optimizer',
    task: 'inference',
    tier: 1,
    telemetry: samples[samples.length - 1],
    zkProof: result.proof,
  });

  const opt = optimizeTick({
    workers: [{ tokensPerSec: 100, costPerHourUsd: 0.7, uptimePct: 99, utilizationPct: 70, wattsPerToken: 1.1, thermalC: 72, vramUsedPct: 65, packetLossPct: 0.2, url: 'https://5090.akash' }],
    nft: { tier: 1 },
    zkProof: result.proof,
  });

  console.log(JSON.stringify({
    ok: result.proof.ok,
    seed: result.seed.slice(0, 18) + '...',
    proofMode: result.proof.mode,
    entropyQuality: result.entropyQuality,
    genomeHash: genome.genomeHash.slice(0, 18) + '...',
    queueBatch: batch.length,
    routeOk: route.ok,
    optimizerScore: opt.signal?.compositeScore,
    zkFeedback: applyZkFeedback(result.proof),
    layers: result.layers,
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
