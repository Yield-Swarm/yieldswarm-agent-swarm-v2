/**
 * Great Delta emission router treasury splits — 50/30/15/5.
 * Used by payment rails to display DePIN + treasury allocation on settlements.
 */

export const GREAT_DELTA_SPLIT_BPS = {
  coreTreasury: 5000,
  growthTreasury: 3000,
  insuranceTreasury: 1500,
  opsTreasury: 500,
} as const;

export type SplitBucket = keyof typeof GREAT_DELTA_SPLIT_BPS;

export function allocateEmission(amountUsd: string, bucket: SplitBucket): string {
  const total = Object.values(GREAT_DELTA_SPLIT_BPS).reduce((a, b) => a + b, 0);
  const bps = GREAT_DELTA_SPLIT_BPS[bucket];
  const value = (parseFloat(amountUsd) * bps) / total;
  return value.toFixed(4);
}

export function emissionBreakdown(amountUsd: string): Record<SplitBucket, string> {
  return Object.fromEntries(
    (Object.keys(GREAT_DELTA_SPLIT_BPS) as SplitBucket[]).map((k) => [
      k,
      allocateEmission(amountUsd, k),
    ]),
  ) as Record<SplitBucket, string>;
}
