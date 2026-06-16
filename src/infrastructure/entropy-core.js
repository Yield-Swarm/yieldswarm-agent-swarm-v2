/**
 * Entropy Core — hardware telemetry → ZK-ready witnesses (E¹ + ZK¹ + PDs¹).
 *
 * Five-layer helical integration:
 *   D¹    — bounded normalization, typed circuit inputs
 *   E¹    — rolling windows, emergence-friendly vectors
 *   C¹+L¹ — window nonce for rhythmic proof batches
 *   ZK¹   — public/private signal separation for Groth16
 *   PDs¹  — seeds drive NFT co-evolution
 *
 * @module src/infrastructure/entropy-core
 */

import { createHash, randomBytes } from 'node:crypto';

export const TELEMETRY_KEYS = Object.freeze([
  'gpuTempC',
  'vramUsedPct',
  'powerWatts',
  'hashRate',
  'packetLossPct',
  'inferenceTps',
  'arenaRoiBps',
]);

export const NODE_PROFILES = Object.freeze({
  rtx5090: 0,
  h100: 1,
  rtx3090: 2,
  other: 2,
});

const LIMITS = Object.freeze({
  gpuTempC: 100,
  vramUsedPct: 100,
  powerWatts: 600,
  hashRate: 1e15,
  packetLossPct: 100,
  inferenceTps: 200,
  arenaRoiBps: 10_000,
});

const DEFAULT_WINDOW_SIZE = 8;

/**
 * Normalize telemetry snapshot to stable 0..1 vector (E¹ Task 11).
 * @param {Record<string, number>} raw
 */
export function normalizeTelemetry(raw) {
  const vec = {};
  for (const key of TELEMETRY_KEYS) {
    const v = Number(raw[key] ?? 0);
    vec[key] = clamp01(v / (LIMITS[key] ?? 100));
  }
  return vec;
}

/**
 * Circuit-friendly integer scaling (E¹ Task 19).
 * @param {Record<string, number>} raw
 * @param {string} [nodeProfile]
 */
export function toCircuitInputs(raw, nodeProfile = 'rtx5090') {
  return {
    gpuTempScaled: clampInt(raw.gpuTempC, 0, 100),
    vramScaled: clampInt(raw.vramUsedPct, 0, 100),
    powerScaled: clampInt(raw.powerWatts, 0, 600),
    inferenceTpsScaled: clampInt(raw.inferenceTps, 0, 200),
    packetLossScaled: clampInt(Math.round(Number(raw.packetLossPct ?? 0)), 0, 100),
    nodeProfile: NODE_PROFILES[nodeProfile] ?? NODE_PROFILES.other,
  };
}

/**
 * Rolling window aggregator for rhythmic ZK batches (E¹ Task 12, C¹+L¹ Task 21).
 * @param {Record<string, number>[]} samples
 * @param {number} [windowSize]
 */
export function buildRollingWindow(samples, windowSize = DEFAULT_WINDOW_SIZE) {
  const window = samples.slice(-windowSize);
  if (window.length === 0) return null;

  const agg = {};
  for (const key of TELEMETRY_KEYS) {
    const vals = window.map((s) => Number(s[key] ?? 0)).filter(Number.isFinite);
    agg[key] = vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : 0;
  }

  return {
    aggregated: agg,
    windowSize: window.length,
    nonce: window.length,
    entropyQuality: computeEntropyQuality(window),
    samples: window,
  };
}

/**
 * Split public vs private ZK witness (ZK¹ Task 11).
 * @param {object} scaled from toCircuitInputs + tokenId/nonce
 * @param {Record<string, number>} [rawTelemetry]
 */
export function buildZkWitness(scaled, rawTelemetry = {}) {
  const circuitInput = {
    gpuTempScaled: fieldStr(scaled.gpuTempScaled),
    vramScaled: fieldStr(scaled.vramScaled),
    powerScaled: fieldStr(scaled.powerScaled),
    inferenceTpsScaled: fieldStr(scaled.inferenceTpsScaled),
    packetLossScaled: fieldStr(scaled.packetLossScaled),
    tokenId: fieldStr(scaled.tokenId),
    nonce: fieldStr(scaled.nonce),
    nodeProfile: fieldStr(scaled.nodeProfile),
  };

  const entropySeed = hashDevSeed(circuitInput);

  return {
    public: { entropySeed },
    private: { ...circuitInput, rawTelemetry },
    circuitInput: { ...circuitInput, entropySeed },
  };
}

function fieldStr(v) {
  if (typeof v === 'bigint') return v.toString();
  return String(v ?? 0);
}

/**
 * Structured ZK-ready output (E¹ Task 11).
 */
export function deriveZkEntropyBundle(telemetry, tokenId = '0', opts = {}) {
  const window = opts.window ?? buildRollingWindow(opts.samples ?? [telemetry]);
  const source = window?.aggregated ?? telemetry;
  const profile = source.nodeProfile ?? telemetry.nodeProfile ?? 'rtx5090';
  const scaled = {
    ...toCircuitInputs(source, profile),
    tokenId: BigInt(String(tokenId).replace(/\D/g, '') || '0'),
    nonce: BigInt(window?.nonce ?? 0),
  };

  const witness = buildZkWitness(scaled, source);
  const vector = normalizeTelemetry(source);

  return {
    publicInputs: witness.public,
    privateInputs: witness.private,
    circuitInput: witness.circuitInput,
    vector,
    entropyQuality: window?.entropyQuality ?? computeEntropyQuality([source]),
    window,
    nodeProfile: profile,
    layers: {
      greek: 'bounded_circuit_inputs',
      eastern: 'rolling_window_emergence',
      helix: `window_${window?.windowSize ?? 1}`,
      zk: 'poseidon_bound',
      paradigm: 'co_evolution_ready',
    },
  };
}

/**
 * Generate entropy seed + Groth16 proof in one call (E¹ Mayhem Task 11-20).
 * @param {Record<string, number>} telemetry
 * @param {string|number} tokenId
 * @param {object} [opts]
 * @param {import('./zk-entropy-prover.js').ZkEntropyProver} [opts.prover]
 * @param {Record<string, number>[]} [opts.samples] rolling window samples
 */
export async function generateSeedWithProof(telemetry, tokenId = '0', opts = {}) {
  const bundle = deriveZkEntropyBundle(telemetry, tokenId, {
    samples: opts.samples,
    window: opts.window,
  });

  const { ZkEntropyProver } = await import('./zk-entropy-prover.js');
  const prover = opts.prover ?? new ZkEntropyProver({ circuitVersion: opts.circuitVersion ?? '1.0.0' });

  const source = bundle.window?.aggregated ?? telemetry;
  const proofResult = await prover.generateProof({
    telemetry: { ...source, nodeProfile: bundle.nodeProfile },
    tokenId,
    nonce: bundle.window?.nonce ?? 0,
  });

  return {
    seed: proofResult.publicSignals?.entropySeed
      ? `0x${BigInt(proofResult.publicSignals.entropySeed).toString(16).padStart(64, '0').slice(-64)}`
      : deriveMutationSeed(telemetry, tokenId).seed,
    bundle,
    proof: proofResult,
    entropyQuality: bundle.entropyQuality,
    publicInputs: bundle.publicInputs,
    privateInputs: bundle.privateInputs,
    layers: {
      ...bundle.layers,
      eastern: proofResult.ok ? 'seed_with_proof' : 'seed_degraded',
      zk: proofResult.mode ?? 'none',
      paradigm: 'mutation_ready',
    },
  };
}

/**
 * Legacy seed derivation (backward compatible).
 */
export function deriveMutationSeed(telemetry, tokenId = '0') {
  const bundle = deriveZkEntropyBundle(telemetry, tokenId);
  const seedBytes = createHash('sha256').update(JSON.stringify(bundle.publicInputs)).digest();
  return {
    seed: `0x${seedBytes.toString('hex')}`,
    seedBytes,
    vector: bundle.vector,
    zk: bundle,
    layers: bundle.layers,
  };
}

export function proposeGenomeDelta(currentGenome, seed) {
  const hash = createHash('sha256').update(seed).digest();
  const genes = [
    'aggressionBps', 'providerLoyaltyBps', 'riskAppetiteBps',
    'creditBufferBps', 'rebalanceBiasBps',
  ];

  const next = { ...currentGenome };
  for (let i = 0; i < genes.length; i++) {
    const gene = genes[i];
    const delta = ((hash[i] - 128) / 128) * 400;
    next[gene] = clampBps((currentGenome[gene] ?? 5000) + delta);
  }
  next.mutationEpoch = (currentGenome.mutationEpoch ?? 0) + 1;
  next.lastMutationAt = Math.floor(Date.now() / 1000);

  const genomeHash = `0x${createHash('sha256').update(JSON.stringify(next)).digest('hex')}`;
  return { genome: next, genomeHash };
}

function computeEntropyQuality(samples) {
  if (!samples.length) return 0;
  const temps = samples.map((s) => Number(s.gpuTempC ?? 0));
  const tps = samples.map((s) => Number(s.inferenceTps ?? 0));
  const tempVar = variance(temps);
  const tpsMean = tps.reduce((a, b) => a + b, 0) / tps.length;
  return clamp01(0.4 * (1 - tempVar / 500) + 0.6 * (tpsMean / 200));
}

function variance(arr) {
  if (arr.length < 2) return 0;
  const mean = arr.reduce((a, b) => a + b, 0) / arr.length;
  return arr.reduce((s, x) => s + (x - mean) ** 2, 0) / arr.length;
}

function hashDevSeed(input) {
  const h = createHash('sha256').update(JSON.stringify(input)).digest('hex');
  return BigInt(`0x${h.slice(0, 16)}`).toString();
}

function clampInt(v, min, max) {
  const n = Math.floor(Number(v));
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}

function clamp01(n) {
  return Math.max(0, Math.min(1, Number(n) || 0));
}

function clampBps(n) {
  return Math.max(0, Math.min(10_000, Math.round(Number(n) || 0)));
}

export default {
  normalizeTelemetry,
  toCircuitInputs,
  buildRollingWindow,
  buildZkWitness,
  deriveZkEntropyBundle,
  deriveMutationSeed,
  generateSeedWithProof,
  proposeGenomeDelta,
  NODE_PROFILES,
  TELEMETRY_KEYS,
};
