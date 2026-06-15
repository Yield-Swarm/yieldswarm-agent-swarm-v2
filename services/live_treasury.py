"""Live treasury overlay for the sovereign runtime.

Maps the Great Delta 50/30/15/5 split onto :class:`YieldStrategy` books and
computes rebalance transfers when bucket weights drift from policy.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parents[1]

# Canonical Great Delta split — mirrors backend/src/lib/great-delta-split.js
GREAT_DELTA_BPS = {
    "coreTreasury": 5000,
    "growthTreasury": 3000,
    "insuranceTreasury": 1500,
    "opsTreasury": 500,
}

BUCKET_LABELS = {
    "coreTreasury": "Core Treasury",
    "growthTreasury": "Growth Treasury",
    "insuranceTreasury": "Insurance Treasury",
    "opsTreasury": "Ops Treasury",
}

# Default APY / risk priors per bucket for the sovereign rebalancer.
BUCKET_PROFILES = {
    "coreTreasury": {"apy": 0.10, "risk": 0.10, "baseline_apy": 0.08},
    "growthTreasury": {"apy": 0.22, "risk": 0.35, "baseline_apy": 0.20},
    "insuranceTreasury": {"apy": 0.06, "risk": 0.05, "baseline_apy": 0.05},
    "opsTreasury": {"apy": 0.28, "risk": 0.45, "baseline_apy": 0.25},
}

FALLBACK_TREASURY_USD = 1_850_000.0
DEFAULT_SOL_USD = float(os.getenv("SOL_USD_PRICE", "145"))


@dataclass
class TreasuryOverlay:
    source: str
    live: bool
    total_usd: float
    splits: List[Dict[str, Any]]
    error: Optional[str] = None


def _fetch_json(url: str, path: str = "", timeout: float = 8.0) -> Optional[Dict[str, Any]]:
    target = f"{url.rstrip('/')}{path}"
    try:
        req = urllib.request.Request(target, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError):
        return None


def fetch_treasury_overlay() -> TreasuryOverlay:
    """Load treasury splits from backend API or deterministic fallback."""
    backend = os.getenv("YIELDSWARM_BACKEND_URL", "").strip()
    if backend:
        data = _fetch_json(backend, "/api/telemetry/treasury")
        if data and "splits" in data:
            total_sol = float(data.get("totalSol", 0))
            sol_usd = float(os.getenv("SOL_USD_PRICE", str(DEFAULT_SOL_USD)))
            total_usd = total_sol * sol_usd
            splits = []
            for row in data.get("splits", []):
                bucket = row.get("bucket", "coreTreasury")
                sol = float(row.get("sol", 0))
                splits.append({
                    "bucket": bucket,
                    "label": row.get("label") or BUCKET_LABELS.get(bucket, bucket),
                    "bps": int(row.get("bps", 0)),
                    "pct": float(row.get("pct", 0)),
                    "sol": sol,
                    "usd": round(sol * sol_usd, 2),
                })
            return TreasuryOverlay(
                source=data.get("source", "backend"),
                live=bool(data.get("live")),
                total_usd=round(total_usd, 2),
                splits=splits,
            )

    # Local cache written by ops / CI
    cache_path = REPO_ROOT / ".run" / "treasury-overlay.json"
    if cache_path.is_file():
        try:
            data = json.loads(cache_path.read_text(encoding="utf-8"))
            return TreasuryOverlay(
                source=data.get("source", "cache"),
                live=bool(data.get("live")),
                total_usd=float(data.get("total_usd", FALLBACK_TREASURY_USD)),
                splits=list(data.get("splits", [])),
            )
        except (OSError, json.JSONDecodeError, TypeError, ValueError):
            pass

    total_usd = FALLBACK_TREASURY_USD
    splits = _split_usd(total_usd)
    return TreasuryOverlay(
        source="fallback",
        live=False,
        total_usd=total_usd,
        splits=splits,
        error="no live treasury source",
    )


def _split_usd(total_usd: float) -> List[Dict[str, Any]]:
    entries = list(GREAT_DELTA_BPS.items())
    head = entries[:-1]
    allocated = 0.0
    rows: List[Dict[str, Any]] = []
    for bucket, bps in head:
        usd = round(total_usd * bps / 10_000, 2)
        allocated += usd
        rows.append({
            "bucket": bucket,
            "label": BUCKET_LABELS[bucket],
            "bps": bps,
            "pct": round(bps / 100, 2),
            "usd": usd,
        })
    last_bucket, last_bps = entries[-1]
    rows.append({
        "bucket": last_bucket,
        "label": BUCKET_LABELS[last_bucket],
        "bps": last_bps,
        "pct": round(last_bps / 100, 2),
        "usd": round(total_usd - allocated, 2),
    })
    return rows


def overlay_to_strategies(overlay: TreasuryOverlay) -> List[Any]:
    """Convert overlay splits into iteration-100 YieldStrategy objects."""
    import sys

    iter_path = str(REPO_ROOT / "iteration-100")
    if iter_path not in sys.path:
        sys.path.insert(0, iter_path)
    from core.state import YieldStrategy

    strategies: List[YieldStrategy] = []
    for row in overlay.splits:
        bucket = row.get("bucket", "coreTreasury")
        profile = BUCKET_PROFILES.get(bucket, BUCKET_PROFILES["coreTreasury"])
        weight = float(row.get("bps", 0)) / 10_000
        strategies.append(YieldStrategy(
            name=BUCKET_LABELS.get(bucket, bucket),
            allocation_usd=float(row.get("usd", overlay.total_usd * weight)),
            apy=profile["apy"],
            risk=profile["risk"],
            liquid=True,
            baseline_apy=profile["baseline_apy"],
        ))
    return strategies


def compute_policy_rebalance(
    overlay: TreasuryOverlay,
    *,
    band_pct: float = 0.03,
) -> Tuple[List[Dict[str, Any]], float]:
    """Compute 50/30/15/5 drift corrections (mirrors DynamicTreasuryRebalancingLoop)."""
    actions: List[Dict[str, Any]] = []
    total = overlay.total_usd
    if total <= 0:
        return actions, 0.0

    moved = 0.0
    for row in overlay.splits:
        bucket = row.get("bucket", "")
        bps = int(row.get("bps", 0))
        target_usd = total * bps / 10_000
        current_usd = float(row.get("usd", 0))
        drift = current_usd - target_usd
        band = max(450.0, band_pct * target_usd)
        if abs(drift) > band:
            transfer = round(-drift * 0.60, 2)
            row["usd"] = round(current_usd + transfer, 2)
            moved += abs(transfer)
            actions.append({
                "bucket": bucket,
                "label": row.get("label", bucket),
                "transfer_usd": transfer,
                "post_allocation_usd": row["usd"],
                "target_usd": round(target_usd, 2),
            })
    return actions, moved


def write_treasury_overlay(overlay: TreasuryOverlay, path: Optional[Path] = None) -> None:
    out = path or (REPO_ROOT / ".run" / "treasury-overlay.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "source": overlay.source,
        "live": overlay.live,
        "total_usd": overlay.total_usd,
        "splits": overlay.splits,
        "error": overlay.error,
    }
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
