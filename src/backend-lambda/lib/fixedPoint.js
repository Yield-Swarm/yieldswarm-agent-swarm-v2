/**
 * Fixed-point reward engine — 10^9 nano scale (TVM-aligned).
 */
const ATTO_SCALE = 1_000_000_000n;
const MAX_ALLOCATION_PER_TX = 500n * ATTO_SCALE;

function computeRewardAllocation(actionData) {
  const baseScalingK = BigInt(Math.floor(actionData.baseFactor * 1000));
  const normalizedLvl = BigInt(actionData.enemyLevel);
  const clampedDeltaTime = BigInt(Math.min(Math.max(actionData.deltaTime, 1), 3600));
  let allocation = (baseScalingK * normalizedLvl * clampedDeltaTime * ATTO_SCALE) / 1000n;
  if (allocation > MAX_ALLOCATION_PER_TX) allocation = MAX_ALLOCATION_PER_TX;
  return allocation;
}

module.exports = { ATTO_SCALE, MAX_ALLOCATION_PER_TX, computeRewardAllocation };
