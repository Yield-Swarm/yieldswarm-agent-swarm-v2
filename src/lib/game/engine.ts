import type { PoEActionInput, PoEActionType } from "@/types/game";

/** Hard caps — economic firewall inside each claim. */
export const POE_MAX_DELTA_SECONDS = 3_600;
export const POE_DEFAULT_DELTA_SECONDS = 60;
export const POE_MAX_EMISSION = 1_000_000n;
export const POE_MIN_EMISSION = 1n;

const ACTION_MULTIPLIER: Record<PoEActionType, number> = {
  combat: 1.0,
  crafting: 0.85,
  exploration: 1.1,
  social: 0.7,
};

/**
 * Bounded Proof-of-Engagement emission.
 * deltaTime must be supplied server-side from on-chain lastSaveTimestamp.
 */
export function calculatePoEEmission(action: PoEActionInput): bigint {
  const { baseFactor, metrics, weights, actionType } = action;

  if (metrics.length !== weights.length) {
    throw new Error("metrics and weights length mismatch");
  }

  const deltaTime = Math.min(
    Math.max(0, action.deltaTime ?? POE_DEFAULT_DELTA_SECONDS),
    POE_MAX_DELTA_SECONDS,
  );

  if (deltaTime === 0) return 0n;

  let weightedScore = 0;
  for (let i = 0; i < metrics.length; i++) {
    const metric = Math.min(metrics[i]!, 1_000);
    const weight = Math.min(weights[i]!, 100);
    weightedScore += metric * weight;
  }

  const typeMul = ACTION_MULTIPLIER[actionType];
  const raw =
    (baseFactor * weightedScore * deltaTime * typeMul) / (metrics.length * 100);

  if (!Number.isFinite(raw) || raw <= 0) return 0n;

  const emission = BigInt(Math.floor(raw));
  if (emission < POE_MIN_EMISSION) return 0n;
  if (emission > POE_MAX_EMISSION) return POE_MAX_EMISSION;
  return emission;
}

/** Server-side delta from authoritative last-save timestamp (unix seconds). */
export function computeServerDeltaTime(
  onChainLastSave: number,
  currentUnixTime: number,
): number {
  if (onChainLastSave <= 0) return POE_DEFAULT_DELTA_SECONDS;
  const delta = Math.max(0, currentUnixTime - onChainLastSave);
  return Math.min(delta, POE_MAX_DELTA_SECONDS);
}
