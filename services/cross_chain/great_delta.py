"""Great Delta treasury routing for cross-chain execution revenue."""

from __future__ import annotations

from typing import Any, Dict, Mapping

from agents.governance.gospel import TREASURY_SPLIT_BPS

BUCKET_NAMES = (
    "coreTreasury",
    "growthTreasury",
    "insuranceTreasury",
    "opsTreasury",
)


def route_revenue_to_treasury(
    amount_usd: float,
    *,
    source: str,
    strategy: str,
) -> Dict[str, Any]:
    """Split gross revenue into 50/30/15/5 buckets (zero-dust remainder to ops)."""
    if amount_usd < 0:
        raise ValueError("amount_usd must be non-negative")

    bps = TREASURY_SPLIT_BPS
    total_bps = sum(bps)
    to_core = amount_usd * bps[0] / total_bps
    to_growth = amount_usd * bps[1] / total_bps
    to_insurance = amount_usd * bps[2] / total_bps
    to_ops = amount_usd - to_core - to_growth - to_insurance

    split = {
        "coreTreasury": round(to_core, 8),
        "growthTreasury": round(to_growth, 8),
        "insuranceTreasury": round(to_insurance, 8),
        "opsTreasury": round(to_ops, 8),
    }

    return {
        "source": source,
        "strategy": strategy,
        "gross_usd": round(amount_usd, 8),
        "split_usd": split,
        "bps": {
            "coreTreasury": bps[0],
            "growthTreasury": bps[1],
            "insuranceTreasury": bps[2],
            "opsTreasury": bps[3],
        },
    }


def aggregate_splits(receipts: Mapping[str, Mapping[str, Any]]) -> Dict[str, float]:
    """Sum treasury buckets across multiple execution receipts."""
    totals = {k: 0.0 for k in BUCKET_NAMES}
    for receipt in receipts.values():
        split = receipt.get("treasury_split", {}).get("split_usd", {})
        for bucket in BUCKET_NAMES:
            totals[bucket] += float(split.get(bucket, 0.0))
    return {k: round(v, 8) for k, v in totals.items()}
