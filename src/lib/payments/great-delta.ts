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

/** Legacy quadrant-IV labels (same ratios). */
export const LEGACY_SPLIT_PCT = {
  vault: 50,
  operations: 30,
  ecosystem: 15,
  sovereignReserve: 5,
} as const;

export type SplitBucket = keyof typeof GREAT_DELTA_SPLIT_BPS;

const LEGACY_TO_CANONICAL: Record<keyof typeof LEGACY_SPLIT_PCT, SplitBucket> = {
  vault: "coreTreasury",
  operations: "growthTreasury",
  ecosystem: "insuranceTreasury",
  sovereignReserve: "opsTreasury",
};

export function allocateEmission(amountUsd: string, bucket: SplitBucket): string {
  const total = Object.values(GREAT_DELTA_SPLIT_BPS).reduce((a, b) => a + b, 0);
  const bps = GREAT_DELTA_SPLIT_BPS[bucket];
  const value = (parseFloat(amountUsd) * bps) / total;
  return value.toFixed(4);
}

export function emissionBreakdown(amountUsd: string): Record<SplitBucket, string> {
  const rows = Object.fromEntries(
    (Object.keys(GREAT_DELTA_SPLIT_BPS) as SplitBucket[]).map((k) => [
      k,
      allocateEmission(amountUsd, k),
    ]),
  ) as Record<SplitBucket, string>;

  // Zero-dust: remainder to opsTreasury (matches on-chain previewSplit).
  const sum = Object.values(rows).reduce((s, v) => s + parseFloat(v), 0);
  const remainder = parseFloat(amountUsd) - sum;
  if (Math.abs(remainder) > 1e-9) {
    rows.opsTreasury = (parseFloat(rows.opsTreasury) + remainder).toFixed(4);
  }
  return rows;
}

export function emissionBreakdownWithLegacy(amountUsd: string) {
  const canonical = emissionBreakdown(amountUsd);
  const legacy = Object.fromEntries(
    Object.entries(LEGACY_TO_CANONICAL).map(([legacyKey, canonicalKey]) => [
      legacyKey,
      canonical[canonicalKey],
    ]),
  );
  return { canonical, legacy, policy: "50/30/15/5" as const };
}
