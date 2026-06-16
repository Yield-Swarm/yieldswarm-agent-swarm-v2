/**
 * Entropy Core — hardware telemetry → cryptographic mutation seeds (E¹ + PDs¹).
 *
 * Converts raw GPU/thermal/network telemetry into structured seeds that
 * influence weekly NFT mutation via Chainlink Functions + Automation.
 *
 * @module src/infrastructure/entropy-core
 */

import { createHash, randomBytes } from 'node:crypto';

const TELEMETRY_KEYS = [
  'gpuTempC',
  'vramUsedPct',
  'powerWatts',
  'hashRate',
  'packetLossPct',
  'inferenceTps',
  'arenaRoiBps',
];

/**
 * Normalize telemetry snapshot to stable 0..1 vector.
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

const LIMITS = Object.freeze({
  gpuTempC: 100,
  vramUsedPct: 100,
  powerWatts: 600,
  hashRate: 1e15,
  packetLossPct: 100,
  inferenceTps: 200,
  arenaRoiBps: 10_000,
});

/**
 * Derive mutation entropy seed from telemetry + optional NFT tokenId salt.
 * @param {Record<string, number>} telemetry
 * @param {string|number} [tokenId]
 * @returns {{ seed: string, seedBytes: Buffer, vector: object, layers: object }}
 */
export function deriveMutationSeed(telemetry, tokenId = '0') {
  const vector = normalizeTelemetry(telemetry);
  const payload = JSON.stringify({
    tokenId: String(tokenId),
    vector,
    nonce: randomBytes(8).toString('hex'),
    ts: Date.now(),
  });

  const seedBytes = createHash('sha256').update(payload).digest();
  const seed = `0x${seedBytes.toString('hex')}`;

  return {
    seed,
    seedBytes,
    vector,
    layers: {
      greek: 'deterministic_hash',
      eastern: 'telemetry_emergence',
      paradigm: 'co_evolution_seed',
    },
  };
}

/**
 * Propose genome delta from entropy seed (mirrors iteration-100/agent_mutation.py genes).
 * @param {object} currentGenome bps values 0..10000
 * @param {string} seed hex seed from deriveMutationSeed
 */
export function proposeGenomeDelta(currentGenome, seed) {
  const hash = createHash('sha256').update(seed).digest();
  const genes = [
    'aggressionBps',
    'providerLoyaltyBps',
    'riskAppetiteBps',
    'creditBufferBps',
    'rebalanceBiasBps',
  ];

  const next = { ...currentGenome };
  for (let i = 0; i < genes.length; i++) {
    const gene = genes[i];
    const delta = ((hash[i] - 128) / 128) * 400; // ±400 bps max shift
    next[gene] = clampBps((currentGenome[gene] ?? 5000) + delta);
  }
  next.mutationEpoch = (currentGenome.mutationEpoch ?? 0) + 1;
  next.lastMutationAt = Math.floor(Date.now() / 1000);

  const genomeHash = `0x${createHash('sha256').update(JSON.stringify(next)).digest('hex')}`;
  return { genome: next, genomeHash };
}

function clamp01(n) {
  return Math.max(0, Math.min(1, Number(n) || 0));
}

function clampBps(n) {
  return Math.max(0, Math.min(10_000, Math.round(Number(n) || 0)));
}

export default { normalizeTelemetry, deriveMutationSeed, proposeGenomeDelta };
