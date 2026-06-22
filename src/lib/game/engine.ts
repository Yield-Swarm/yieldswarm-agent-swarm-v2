import type { ProofOfEngagementAction } from "@/types/game";

/** Fixed-point scale — 9 decimals (nano-token / Jetton standard). */
export const POE_SCALE = 1_000_000_000n;

/** Absolute cap per claim (500 IGJ in nano units). */
export const MAX_EMISSION_PER_ACTION = 500n * POE_SCALE;

/** Min/max Δt bounds — prevents offline exploitation. */
export const MIN_DELTA_SECONDS = 1;
export const MAX_DELTA_SECONDS = 3600;

const ACTION_MODIFIERS: Record<ProofOfEngagementAction["actionType"], bigint> = {
  combat: (POE_SCALE * 125n) / 100n, // 1.25x
  crafting: (POE_SCALE * 110n) / 100n, // 1.10x
  exploration: (POE_SCALE * 95n) / 100n, // 0.95x
  social: POE_SCALE, // 1.0x
};

/**
 * Hardened Proof-of-Engagement fixed-point emission engine.
 * All math uses bigint — no floating-point drift.
 */
export function calculatePoEEmission(action: ProofOfEngagementAction): bigint {
  const boundedDelta = Math.min(
    Math.max(action.deltaTime, MIN_DELTA_SECONDS),
    MAX_DELTA_SECONDS,
  );

  const k = BigInt(Math.floor(action.baseFactor * 1000));
  const enemyLevel = BigInt(action.enemyLevel);
  const precision = BigInt(Math.floor(action.precision * 1000));
  const dt = BigInt(boundedDelta);

  if (precision === 0n) return 0n;

  const baseReward = (k * enemyLevel * dt) / precision;
  const modifier = ACTION_MODIFIERS[action.actionType] ?? POE_SCALE;
  let finalEmission = (baseReward * modifier) / POE_SCALE;

  if (finalEmission < 0n) return 0n;
  if (finalEmission > MAX_EMISSION_PER_ACTION) {
    finalEmission = MAX_EMISSION_PER_ACTION;
  }

  return finalEmission;
}

/** Convert nano emission to display number (for UI only — not for on-chain math). */
export function emissionNanoToDisplay(nano: bigint): number {
  return Number(nano) / Number(POE_SCALE);
}
