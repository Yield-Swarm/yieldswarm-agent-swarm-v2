"""2026 mining profitability intelligence — ranks coins for our hardware."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[1]
RANKINGS_PATH = REPO_ROOT / "config" / "mining" / "coin-rankings.json"


def load_rankings() -> Dict[str, Any]:
    if not RANKINGS_PATH.exists():
        return {"rankings": [], "hardware_tiers": {}}
    return json.loads(RANKINGS_PATH.read_text(encoding="utf-8"))


def top_coins_for_tier(tier: str, limit: int = 5) -> List[Dict[str, Any]]:
    data = load_rankings()
    results: List[Dict[str, Any]] = []
    for row in data.get("rankings", []):
        best = row.get("best_for", [])
        if tier in best or tier == "unknown":
            usd_raw = row.get("est_usd_per_day", {}).get(tier)
            try:
                usd = float(usd_raw) if usd_raw is not None else None
            except (TypeError, ValueError):
                usd = None
            results.append({
                "rank": row.get("rank"),
                "coin": row.get("coin"),
                "algorithm": row.get("algorithm"),
                "est_usd_per_day": usd,
                "pool_hint": row.get("pool_hint"),
                "miner": row.get("miner"),
            })
    results.sort(key=lambda r: (r.get("est_usd_per_day") or 0.0), reverse=True)
    return results[:limit]


def profitability_report(hardware: str = "h100_sxm") -> Dict[str, Any]:
    data = load_rankings()
    tier = hardware.lower().replace(" ", "_")
    top = top_coins_for_tier(tier)
    strategy = data.get("free_credit_strategy", {})

    return {
        "hardware_tier": tier,
        "top_coins": top,
        "recommendation": {
            "gpu_primary": "KAS (kHeavyHash) on NiceHash or direct pool",
            "gpu_secondary": "QUBIC AI training lease on H100/H200/B200",
            "cpu_residual": "XMR (RandomX) on spare EPYC/Xeon threads",
            "akash_first": strategy.get("akash_rtx3090", ["TAO", "KAS"]),
            "runpod_first": strategy.get("runpod_h100_h200_b200", ["KAS", "QUBIC"]),
        },
        "updated": data.get("updated"),
        "disclaimer": "Verify live rates before mainnet wallet routing.",
    }
