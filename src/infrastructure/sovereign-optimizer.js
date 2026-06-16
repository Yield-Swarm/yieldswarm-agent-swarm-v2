/**
 * Sovereign Optimizer v6 — multi-objective optimization + Alpha-Zeta wormhole routing.
 *
 * Five-layer helical integration:
 *   D¹    — auditable scoring weights and hard resource limits
 *   E¹    — probabilistic wormhole routing, ZK proof feedback loops
 *   C¹+L¹ — proof timing signals influence routing rhythm
 *   ZK¹   — high-quality entropy proofs boost routing priority
 *   PDs¹  — NFT mutation tier as optimization signal
 *
 * @module src/infrastructure/sovereign-optimizer
 */

const WEIGHTS = Object.freeze({
  speed: 0.22,
  cost: 0.20,
  reliability: 0.24,
  utilization: 0.18,
  energy: 0.16,
});

const THERMAL_LIMIT_C = 85;
const VRAM_PRESSURE_PCT = 92;
const NETWORK_DROP_PCT = 5;
const ZK_PROOF_BOOST_MAX = 0.12; // E¹ Task 18, PDs¹ Task 46

/**
 * @typedef {object} OptimizerSignal
 * @property {number} [mutationTier]
 * @property {number} [mutationBoostBps]
 * @property {string} [wormholeTarget]
 * @property {number} [compositeScore]
 */

/**
 * Score a candidate node/worker across five objectives.
 * @param {object} candidate
 * @param {object} [nftSignal] from on-chain tier + staking boost
 */
export function scoreCandidate(candidate, nftSignal = {}) {
  const tier = nftSignal.mutationTier ?? candidate.tier ?? 0;
  const boostBps = nftSignal.mutationBoostBps ?? 0;
  const tierMultiplier = 1 + tier * 0.08 + boostBps / 10_000;

  // ZK¹ + E¹ — proof quality boosts routing (Tasks 13, 18, 25, 46)
  const zkBoost = computeZkRoutingBoost(nftSignal.zkProof);
  const tierMultiplierWithZk = tierMultiplier * (1 + zkBoost);

  const speed = clamp01(candidate.tokensPerSec / 120);
  const cost = clamp01(1 - candidate.costPerHourUsd / 2.5);
  const reliability = clamp01(candidate.uptimePct / 100);
  const utilization = clamp01(1 - Math.abs(0.72 - candidate.utilizationPct / 100));
  const energy = clamp01(1 - candidate.wattsPerToken / 3.5);

  let composite =
    WEIGHTS.speed * speed +
    WEIGHTS.cost * cost +
    WEIGHTS.reliability * reliability +
    WEIGHTS.utilization * utilization +
    WEIGHTS.energy * energy;

  composite *= tierMultiplierWithZk;

  // C¹+L¹ — proving time as dynamic routing signal (Task 25)
  if (nftSignal.zkProof?.proveMs > 15_000) composite *= 0.95;
  if (nftSignal.zkProof?.proveMs < 3000 && nftSignal.zkProof?.ok) composite *= 1.03;

  if (candidate.thermalC > THERMAL_LIMIT_C) composite *= 0.5;
  if (candidate.vramUsedPct > VRAM_PRESSURE_PCT) composite *= 0.6;
  if (candidate.packetLossPct > NETWORK_DROP_PCT) composite *= 0.7;

  return {
    compositeScore: round4(composite),
    breakdown: { speed, cost, reliability, utilization, energy, tierMultiplier: tierMultiplierWithZk, zkBoost },
    layers: {
      greek: 'bounded_objectives',
      eastern: 'adaptive_scoring',
      helix: nftSignal.zkProof?.proveMs ? 'proof_timing_aware' : 'standard',
      zk: nftSignal.zkProof?.mode ?? 'none',
      paradigm: `tier_${tier}_boost_${boostBps}`,
    },
  };
}

/**
 * Alpha-Zeta wormhole routing — probabilistic jump to high-yield node.
 * @param {object[]} candidates scored workers
 * @param {object} [arenaFeedback] recent performance from Arena
 */
export function wormholeRoute(candidates, arenaFeedback = {}) {
  if (!candidates.length) return null;

  const scored = candidates
    .map((c) => ({
      ...c,
      ...scoreCandidate(c, {
        mutationTier: arenaFeedback.mutationTier,
        mutationBoostBps: arenaFeedback.mutationBoostBps,
      }),
    }))
    .sort((a, b) => b.compositeScore - a.compositeScore);

  const top = scored[0];
  const zeta = arenaFeedback.entropy ?? Math.random();
  const wormholeProb = 0.15 + top.compositeScore * 0.35 + zeta * 0.1;

  if (Math.random() < wormholeProb && scored.length > 1) {
    const alt = scored[Math.floor(zeta * Math.min(3, scored.length))];
    return {
      wormholeTarget: alt.url ?? alt.workerUrl,
      wormholeReason: 'alpha_zeta_jump',
      compositeScore: alt.compositeScore,
      primary: top,
    };
  }

  return {
    wormholeTarget: top.url ?? top.workerUrl,
    wormholeReason: 'greedy_optimal',
    compositeScore: top.compositeScore,
    primary: top,
  };
}

/**
 * Full optimization tick — ingest Arena + NFT state, emit routing decision.
 */
export function optimizeTick(input) {
  const { workers = [], arena = {}, nft = {}, zkProof = null } = input;
  const signal = wormholeRoute(workers, {
    mutationTier: nft.tier,
    mutationBoostBps: nft.mutationBoostBps,
    entropy: arena.entropy,
    zkProof,
  });

  return {
    ok: true,
    version: 'v6',
    signal,
    weights: WEIGHTS,
    limits: { THERMAL_LIMIT_C, VRAM_PRESSURE_PCT, NETWORK_DROP_PCT },
    zkFeedback: applyZkFeedback(zkProof),
    timestamp: Date.now(),
  };
}

/** E¹ Task 13 — proof success/failure influences future routing */
export function applyZkFeedback(zkProof) {
  if (!zkProof) return { boost: 0, action: 'none' };
  if (!zkProof.ok) return { boost: -0.05, action: 'penalize_failed_proof' };
  const boost = computeZkRoutingBoost(zkProof);
  return { boost, action: boost > 0.05 ? 'prioritize' : 'neutral' };
}

function computeZkRoutingBoost(zkProof) {
  if (!zkProof?.ok) return 0;
  const quality = zkProof.entropyQuality ?? 0.5;
  const modeBonus = zkProof.mode === 'groth16' ? 0.04 : 0.01;
  return Math.min(ZK_PROOF_BOOST_MAX, quality * 0.08 + modeBonus);
}

function clamp01(n) {
  return Math.max(0, Math.min(1, Number(n) || 0));
}

function round4(n) {
  return Math.round(n * 10_000) / 10_000;
}

export default { scoreCandidate, wormholeRoute, optimizeTick, WEIGHTS };
