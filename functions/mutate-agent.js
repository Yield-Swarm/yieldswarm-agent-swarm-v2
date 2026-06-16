/**
 * Chainlink Functions — mutate-agent handler (PDs¹ co-evolution).
 *
 * Deploy to functions/mutate-agent.js and wire as DON JavaScript source.
 * Consumes GPU telemetry + tokenId, returns genomeHash for on-chain execution.
 */

const TELEMETRY_KEYS = [
  'gpuTempC', 'vramUsedPct', 'powerWatts', 'hashRate',
  'packetLossPct', 'inferenceTps', 'arenaRoiBps',
];

const LIMITS = {
  gpuTempC: 100, vramUsedPct: 100, powerWatts: 600,
  hashRate: 1e15, packetLossPct: 100, inferenceTps: 200, arenaRoiBps: 10000,
};

function normalizeTelemetry(raw) {
  const vec = {};
  for (const key of TELEMETRY_KEYS) {
    const v = Number(raw[key] ?? 0);
    vec[key] = Math.max(0, Math.min(1, v / (LIMITS[key] ?? 100)));
  }
  return vec;
}

function sha256Hex(input) {
  // Chainlink Functions provides crypto in sandbox — use built-in if available.
  if (typeof ethers !== 'undefined' && ethers.utils?.keccak256) {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(input));
  }
  // Fallback for local testing
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (Math.imul(31, h) + input.charCodeAt(i)) | 0;
  return '0x' + Math.abs(h).toString(16).padStart(64, '0');
}

function proposeGenomeDelta(current, seedHex) {
  const genes = ['aggressionBps', 'providerLoyaltyBps', 'riskAppetiteBps', 'creditBufferBps', 'rebalanceBiasBps'];
  const next = { ...current };
  for (let i = 0; i < genes.length; i++) {
    const hashByte = parseInt(seedHex.slice(2 + i * 2, 4 + i * 2), 16) || 128;
    const delta = ((hashByte - 128) / 128) * 400;
    next[genes[i]] = Math.max(0, Math.min(10000, Math.round((current[genes[i]] ?? 5000) + delta)));
  }
  next.mutationEpoch = (current.mutationEpoch ?? 0) + 1;
  next.lastMutationAt = Math.floor(Date.now() / 1000);
  const genomeHash = sha256Hex(JSON.stringify(next));
  return { genome: next, genomeHash };
}

// Chainlink Functions entrypoint
async function mutateAgent(args, apiKey, secrets) {
  const tokenId = args[0] ?? secrets.tokenId ?? '0';
  const telemetry = JSON.parse(args[1] ?? secrets.telemetry ?? '{}');
  const currentGenome = JSON.parse(args[2] ?? secrets.currentGenome ?? '{}');

  const vector = normalizeTelemetry(telemetry);
  const payload = JSON.stringify({ tokenId: String(tokenId), vector, ts: Date.now() });
  const entropySeed = sha256Hex(payload);
  const { genome, genomeHash } = proposeGenomeDelta(currentGenome, entropySeed);

  return ethers.utils.defaultAbiCoder.encode(
    ['bytes32', 'bytes32', 'tuple(uint16,uint16,uint16,uint16,uint16,uint8,uint32,uint64)'],
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
    ]
  );
}

// Export for local testing; Chainlink uses mutateAgent directly.
if (typeof module !== 'undefined') module.exports = { mutateAgent, normalizeTelemetry, proposeGenomeDelta };
