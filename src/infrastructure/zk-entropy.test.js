/**
 * @vitest-environment node
 */
import { describe, it, expect } from 'vitest';
import { ZkEntropyProver, ZK_ERROR_CODES } from '../infrastructure/zk-entropy-prover.js';
import {
  deriveZkEntropyBundle,
  buildRollingWindow,
  toCircuitInputs,
  NODE_PROFILES,
} from '../infrastructure/entropy-core.js';
import { ZkProofQueue } from '../infrastructure/zk-proof-queue.js';
import { applyZkFeedback } from '../infrastructure/sovereign-optimizer.js';

describe('entropy-core ZK witness (E¹ Tasks 11-12, 19-20)', () => {
  it('outputs public + private inputs', () => {
    const telemetry = { gpuTempC: 72, vramUsedPct: 55, powerWatts: 420, inferenceTps: 88, packetLossPct: 1 };
    const bundle = deriveZkEntropyBundle(telemetry, '7');
    expect(bundle.publicInputs.entropySeed).toBeDefined();
    expect(bundle.privateInputs.gpuTempScaled).toBeDefined();
    expect(bundle.layers.zk).toBe('poseidon_bound');
  });

  it('builds rolling window with entropy quality', () => {
    const samples = Array.from({ length: 5 }, (_, i) => ({
      gpuTempC: 70 + i, inferenceTps: 80 + i * 2, vramUsedPct: 60,
    }));
    const window = buildRollingWindow(samples);
    expect(window.windowSize).toBe(5);
    expect(window.entropyQuality).toBeGreaterThan(0);
  });

  it('supports RTX5090 and H100 node profiles', () => {
    expect(toCircuitInputs({ gpuTempC: 70, vramUsedPct: 50, powerWatts: 400, inferenceTps: 100 }, 'rtx5090').nodeProfile)
      .toBe(NODE_PROFILES.rtx5090);
    expect(toCircuitInputs({ gpuTempC: 70, vramUsedPct: 50, powerWatts: 400, inferenceTps: 100 }, 'h100').nodeProfile)
      .toBe(NODE_PROFILES.h100);
  });
});

describe('zk-entropy-prover (D¹ + ZK¹ Tasks 5-6, 35-37)', () => {
  it('generates dev-hash proof when artifacts missing', async () => {
    const prover = new ZkEntropyProver();
    const result = await prover.generateProof({
      telemetry: { gpuTempC: 68, vramUsedPct: 70, powerWatts: 350, inferenceTps: 110, packetLossPct: 0.5, nodeProfile: 'rtx5090' },
      tokenId: '42',
      nonce: 3,
    });
    expect(result.ok).toBe(true);
    expect(result.mode).toBe('dev-hash');
    expect(result.publicSignals.entropySeed).toBeDefined();
  });

  it('rejects out-of-range telemetry (D¹ Task 6)', async () => {
    const prover = new ZkEntropyProver();
    const result = await prover.generateProof({
      telemetry: { gpuTempC: 999, vramUsedPct: 50, powerWatts: 100, inferenceTps: 50, packetLossPct: 0 },
      tokenId: '1',
      nonce: 0,
    });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ZK_ERROR_CODES.RANGE_VIOLATION);
  });
});

describe('zk-proof-queue (C¹+L¹ Tasks 21-29)', () => {
  it('defers during high load', () => {
    const queue = new ZkProofQueue();
    queue.enqueue({ tokenId: '1', entropyQuality: 0.9 });
    expect(queue.shouldProcessNow({ utilization: 0.95 })).toBe(false);
    expect(queue.shouldProcessNow({ utilization: 0.5, gpuTempC: 70, vramUsedPct: 60 })).toBe(true);
  });

  it('pauses on thermal pressure', () => {
    const queue = new ZkProofQueue();
    queue.enqueue({ tokenId: '1' });
    expect(queue.shouldProcessNow({ gpuTempC: 90, vramUsedPct: 50, utilization: 0.3 })).toBe(false);
  });

  it('adjusts batch rhythm from prove timing', () => {
    const queue = new ZkProofQueue({ batchSize: 4 });
    queue.adjustRhythm(20_000);
    expect(queue.batchSize).toBe(3);
    queue.adjustRhythm(1000);
    expect(queue.batchSize).toBe(4);
  });
});

describe('sovereign-optimizer ZK feedback (E¹ Task 13, PDs¹ Task 46)', () => {
  it('boosts routing on valid groth16 proof', () => {
    const fb = applyZkFeedback({ ok: true, mode: 'groth16', entropyQuality: 0.9, proveMs: 2000 });
    expect(fb.boost).toBeGreaterThan(0.05);
    expect(fb.action).toBe('prioritize');
  });

  it('penalizes failed proofs', () => {
    const fb = applyZkFeedback({ ok: false });
    expect(fb.boost).toBeLessThan(0);
  });
});

describe('e2e: telemetry → ZK bundle → optimizer (PDs¹ Task 47)', () => {
  it('runs full cycle', async () => {
    const samples = [{ gpuTempC: 71, vramUsedPct: 62, powerWatts: 390, inferenceTps: 92, packetLossPct: 0.8, nodeProfile: 'rtx5090' }];
    const bundle = deriveZkEntropyBundle(samples[0], '99', { samples });
    const prover = new ZkEntropyProver();
    const proof = await prover.generateProof({ telemetry: bundle.window.aggregated, tokenId: '99', nonce: bundle.window.nonce });
    const feedback = applyZkFeedback({ ...proof, entropyQuality: bundle.entropyQuality });
    expect(proof.ok).toBe(true);
    expect(feedback.action).toMatch(/prioritize|neutral/);
  });
});
