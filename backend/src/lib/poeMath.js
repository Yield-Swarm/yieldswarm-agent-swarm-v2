/**
 * Fixed-point Proof of Engagement (10^9 nano scale).
 * Eliminates IEEE 754 drift from v1.0 floating-point math.
 */

const SCALE = 1_000_000_000n;
const MAX_CLAIM_CAP = 500n * SCALE;

/**
 * @param {number} baseFactorRaw e.g. 1.5
 * @param {number} enemyLevel e.g. 8
 * @param {number} deltaTimeSeconds authoritative Δt (1–3600)
 * @returns {bigint} nano-jetton allocation
 */
export function computeHardenedPoEEmission(baseFactorRaw, enemyLevel, deltaTimeSeconds) {
  const k = BigInt(Math.floor(Number(baseFactorRaw) * 1000));
  const lvl = BigInt(Math.max(1, Math.floor(Number(enemyLevel))));
  const dt = BigInt(Math.min(Math.max(Math.floor(Number(deltaTimeSeconds)), 1), 3600));

  let baseRewardScaled = k * lvl * dt;

  let finalEmission;
  if (baseRewardScaled < 50_000n) {
    finalEmission = (baseRewardScaled * SCALE) / 1000n;
  } else {
    finalEmission = ((50_000n + baseRewardScaled / 2n) * SCALE) / 1000n;
  }

  if (finalEmission > MAX_CLAIM_CAP) finalEmission = MAX_CLAIM_CAP;
  return finalEmission;
}

/**
 * Streak multiplier: M = 1.0 + α·ln(1+D), D capped at 6, α=0.5
 * Integer approximation for deterministic server contexts.
 */
export function streakMultiplier(consecutiveDays) {
  const d = Math.min(Math.max(Math.floor(consecutiveDays), 0), 6);
  if (d === 0) return 1.0;
  const lnApprox = Math.log(1 + d);
  return Math.round((1.0 + 0.5 * lnApprox) * 1000) / 1000;
}

export { SCALE, MAX_CLAIM_CAP };
