/**
 * Chainlink Functions — mutate-agent handler (PDs¹ Tasks 43-44).
 *
 * Supports ZK-verified entropy seeds: when zkProof is provided, uses
 * public entropySeed from Groth16; otherwise falls back to hash binding.
 *
 * Args: [tokenId, telemetryJson, currentGenomeJson, zkProofJson?]
 */

const TELEMETRY_KEYS = [
  'gpuTempC', 'vramUsedPct', 'powerWatts', 'hashRate',
  'packetLossPct', 'inferenceTps', 'arenaRoiBps',
];

const NODE_PROFILES = { rtx5090: 0, h100: 1, rtx3090: 2, other: 2 };

const LIMITS = {
  gpuTempC: 100, vramUsedPct: 100, powerWatts: 600,
  hashRate: 1e15, packetLossPct: 100, inferenceTps: 200, arenaRoiBps: 10000,
};

function clampInt(v, min, max) {
  const n = Math.floor(Number(v));
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}

function toCircuitInputs(raw, nodeProfile) {
  return {
    gpuTempScaled: clampInt(raw.gpuTempC, 0, 100),
    vramScaled: clampInt(raw.vramUsedPct, 0, 100),
    powerScaled: clampInt(raw.powerWatts, 0, 600),
    inferenceTpsScaled: clampInt(raw.inferenceTps, 0, 200),
    packetLossScaled: clampInt(Math.round(Number(raw.packetLossPct ?? 0)), 0, 100),
    nodeProfile: NODE_PROFILES[nodeProfile] ?? 2,
  };
}

function normalizeTelemetry(raw) {
  const vec = {};
  for (const key of TELEMETRY_KEYS) {
    const v = Number(raw[key] ?? 0);
    vec[key] = Math.max(0, Math.min(1, v / (LIMITS[key] ?? 100)));
  }
  return vec;
}

function sha256Hex(input) {
  if (typeof ethers !== 'undefined' && ethers.utils?.keccak256) {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(input));
  }
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (Math.imul(31, h) + input.charCodeAt(i)) | 0;
  return '0x' + Math.abs(h).toString(16).padStart(64, '0');
}

function proposeGenomeDelta(current, seedHex) {
  const genes = ['aggressionBps', 'providerLoyaltyBps', 'riskAppetiteBps', 'creditBufferBps', 'rebalanceBiasBps'];
  const next = { ...current };
  for (let i = 0; i < genes.length; i++) {
    const hashByte = parseInt(String(seedHex).slice(2 + i * 2, 4 + i * 2), 16) || 128;
    const delta = ((hashByte - 128) / 128) * 400;
    next[genes[i]] = Math.max(0, Math.min(10000, Math.round((current[genes[i]] ?? 5000) + delta)));
  }
  next.mutationEpoch = (current.mutationEpoch ?? 0) + 1;
  next.lastMutationAt = Math.floor(Date.now() / 1000);
  const genomeHash = sha256Hex(JSON.stringify(next));
  return { genome: next, genomeHash };
}

function buildEntropySeed(telemetry, tokenId, nonce, zkProof) {
  if (zkProof?.publicSignals?.entropySeed) {
    const seed = zkProof.publicSignals.entropySeed;
    return typeof seed === 'bigint' ? '0x' + seed.toString(16) : String(seed);
  }
  const profile = telemetry.nodeProfile ?? 'rtx5090';
  const scaled = toCircuitInputs(telemetry, profile);
  const payload = JSON.stringify({
    tokenId: String(tokenId),
    scaled,
    nonce: nonce ?? 0,
    ts: Date.now(),
  });
  return sha256Hex(payload);
}

// Chainlink Functions entrypoint (PDs¹ Task 43)
async function mutateAgent(args, apiKey, secrets) {
  const tokenId = args[0] ?? secrets.tokenId ?? '0';
  const telemetry = JSON.parse(args[1] ?? secrets.telemetry ?? '{}');
  const currentGenome = JSON.parse(args[2] ?? secrets.currentGenome ?? '{}');
  const zkProof = args[3] ? JSON.parse(args[3]) : (secrets.zkProof ? JSON.parse(secrets.zkProof) : null);

  const entropySeed = buildEntropySeed(telemetry, tokenId, secrets.nonce ?? 0, zkProof);
  const { genome, genomeHash } = proposeGenomeDelta(currentGenome, entropySeed);

  const encoded = ethers.utils.defaultAbiCoder.encode(
    ['bytes32', 'bytes32', 'tuple(uint16,uint16,uint16,uint16,uint16,uint8,uint32,uint64)', 'bool'],
    [
      entropySeed,
      genomeHash,
      [
        genome.aggressionBps ?? 5000,
        genome.providerLoyaltyBps ?? 5000,
        genome.riskAppetiteBps ?? 4000,
        genome.creditBufferBps ?? 6000,
        genome.rebalanceBiasBps ?? 5000,
        genome.tier ?? 0,
        genome.mutationEpoch ?? 1,
        genome.lastMutationAt ?? Math.floor(Date.now() / 1000),
      ],
      Boolean(zkProof?.ok),
    ]
  );

  return encoded;
}

if (typeof module !== 'undefined') {
  module.exports = { mutateAgent, normalizeTelemetry, proposeGenomeDelta, buildEntropySeed, toCircuitInputs };
}
