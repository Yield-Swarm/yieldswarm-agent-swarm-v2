/**
 * Canonical Great Delta 50/30/15/5 treasury split.
 * Mirrors GreatDeltaEmissionRouter.sol previewSplit() and config BPS.
 */

export const BPS_DENOMINATOR = 10_000;

/** Canonical bucket names — matches GreatDeltaEmissionRouter.sol treasuries[0..3]. */
export const GREAT_DELTA_SPLIT_BPS = {
  coreTreasury: 5000,
  growthTreasury: 3000,
  insuranceTreasury: 1500,
  opsTreasury: 500,
};

/** Legacy quadrant-IV / yieldswarm-config labels (same ratios). */
export const LEGACY_SPLIT_PCT = {
  vault: 50,
  operations: 30,
  ecosystem: 15,
  sovereignReserve: 5,
};

/** Map legacy keys → canonical bucket names. */
export const LEGACY_TO_CANONICAL = {
  vault: 'coreTreasury',
  operations: 'growthTreasury',
  ecosystem: 'insuranceTreasury',
  sovereignReserve: 'opsTreasury',
};

export const BUCKET_LABELS = {
  coreTreasury: 'Core Treasury',
  growthTreasury: 'Growth Treasury',
  insuranceTreasury: 'Insurance Treasury',
  opsTreasury: 'Ops Treasury',
};

/**
 * Zero-dust split matching on-chain previewSplit — last bucket gets remainder.
 * @param {number|bigint} amount
 * @returns {Record<string, bigint>}
 */
export function previewSplitBigInt(amount) {
  const n = typeof amount === 'bigint' ? amount : BigInt(Math.trunc(amount));
  const toCore = (n * 50n) / 100n;
  const toGrowth = (n * 30n) / 100n;
  const toInsurance = (n * 15n) / 100n;
  const toOps = n - toCore - toGrowth - toInsurance;
  return {
    coreTreasury: toCore,
    growthTreasury: toGrowth,
    insuranceTreasury: toInsurance,
    opsTreasury: toOps,
  };
}

/**
 * Floating-point split for telemetry dashboards (USD, SOL, APN).
 * @param {number} amount
 * @param {Record<string, number>} [bps]
 */
export function splitAmount(amount, bps = GREAT_DELTA_SPLIT_BPS) {
  const entries = Object.entries(bps);
  const totalBps = entries.reduce((sum, [, v]) => sum + v, 0) || BPS_DENOMINATOR;
  const head = entries.slice(0, -1).map(([bucket, value]) => ({
    bucket,
    label: BUCKET_LABELS[bucket] || bucket,
    bps: value,
    pct: Number(((value / totalBps) * 100).toFixed(2)),
    amount: Number(((amount * value) / totalBps).toFixed(6)),
  }));
  const allocated = head.reduce((s, row) => s + row.amount, 0);
  const [lastBucket, lastBps] = entries[entries.length - 1];
  head.push({
    bucket: lastBucket,
    label: BUCKET_LABELS[lastBucket] || lastBucket,
    bps: lastBps,
    pct: Number(((lastBps / totalBps) * 100).toFixed(2)),
    amount: Number((amount - allocated).toFixed(6)),
  });
  return head;
}

/** Attach legacy alias keys for backward-compatible consumers. */
export function withLegacyAliases(splitByCanonical) {
  const out = { ...splitByCanonical };
  for (const [legacy, canonical] of Object.entries(LEGACY_TO_CANONICAL)) {
    if (canonical in splitByCanonical) {
      out[legacy] = splitByCanonical[canonical];
    }
  }
  return out;
}

export function validateSplitBps(bps = GREAT_DELTA_SPLIT_BPS) {
  const total = Object.values(bps).reduce((a, b) => a + b, 0);
  if (total !== BPS_DENOMINATOR) {
    throw new Error(`Invalid Great Delta split: ${total} bps (expected ${BPS_DENOMINATOR})`);
  }
  return true;
}

export default {
  BPS_DENOMINATOR,
  GREAT_DELTA_SPLIT_BPS,
  LEGACY_SPLIT_PCT,
  LEGACY_TO_CANONICAL,
  BUCKET_LABELS,
  previewSplitBigInt,
  splitAmount,
  withLegacyAliases,
  validateSplitBps,
};
