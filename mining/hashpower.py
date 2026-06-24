"""Hardware hashpower estimation and fleet aggregation."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
RANKINGS_PATH = REPO_ROOT / "config" / "mining" / "coin-rankings.json"
FLEET_PATH = REPO_ROOT / "config" / "mining" / "runpod-fleet.json"


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def gpu_tier_from_name(gpu_name: str) -> str:
    name = gpu_name.upper()
    if "B200" in name:
        return "b200"
    if "H200" in name:
        return "h200_sxm"
    if "H100" in name:
        return "h100_sxm"
    if "4090" in name:
        return "rtx_4090"
    if "3090" in name:
        return "rtx_3090"
    return "unknown"


def estimate_pod_hashpower(pod: Dict[str, Any]) -> Dict[str, Any]:
    tier = gpu_tier_from_name(pod.get("gpu", ""))
    rankings = _load_json(RANKINGS_PATH)
    tiers = rankings.get("hardware_tiers", {})
    tier_meta = tiers.get(tier, {})

    return {
        "pod_id": pod.get("id"),
        "alias": pod.get("alias"),
        "gpu": pod.get("gpu"),
        "tier": tier,
        "vram_gb": tier_meta.get("vram_gb"),
        "est_kaspa_ghs": pod.get("est_kaspa_ghs"),
        "est_xmr_khs": pod.get("est_xmr_khs"),
        "est_usd_per_day_kas": _lookup_daily_usd(rankings, "KAS", tier),
        "est_usd_per_day_qubic": _lookup_daily_usd(rankings, "QUBIC", tier),
    }


def _lookup_daily_usd(rankings: Dict[str, Any], coin: str, tier: str) -> Optional[float]:
    for row in rankings.get("rankings", []):
        if row.get("coin") == coin:
            return row.get("est_usd_per_day", {}).get(tier)
    return None


def fleet_hashpower_report() -> Dict[str, Any]:
    fleet = _load_json(FLEET_PATH)
    pods = fleet.get("pods", [])
    pod_reports = [estimate_pod_hashpower(p) for p in pods]
    totals = fleet.get("fleet_totals", {})

    kas_ghs = sum(p.get("est_kaspa_ghs") or 0 for p in pods)
    xmr_khs = sum(p.get("est_xmr_khs") or 0 for p in pods)
    usd_kas = sum(p.get("est_usd_per_day_kas") or 0 for p in pod_reports)
    usd_qubic = sum(p.get("est_usd_per_day_qubic") or 0 for p in pod_reports)

    return {
        "fleet_region": fleet.get("region"),
        "pod_count": len(pods),
        "pods": pod_reports,
        "totals": {
            "est_kaspa_ghs": round(kas_ghs, 2) or totals.get("est_kaspa_ghs"),
            "est_xmr_khs": totals.get("est_xmr_khs", xmr_khs),
            "est_usd_per_day_gpu_kas": round(usd_kas, 2),
            "est_usd_per_day_gpu_qubic": round(usd_qubic, 2),
            "est_usd_per_day_combined": round(usd_kas + usd_qubic, 2),
        },
        "disclaimer": "Estimates only — run live benchmarks after deploy.",
    }


def measure_live_nvidia() -> Dict[str, Any]:
    """Parse nvidia-smi CSV if available (RunPod pods)."""
    import shutil
    import subprocess

    if not shutil.which("nvidia-smi"):
        return {"available": False, "reason": "nvidia-smi not found (expected on Termux/mobile)"}

    try:
        out = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,memory.total,utilization.gpu,power.draw",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            timeout=10,
        )
        gpus = []
        for line in out.strip().splitlines():
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 4:
                gpus.append({
                    "name": parts[0],
                    "vram_mb": parts[1],
                    "util_pct": parts[2],
                    "power_w": parts[3],
                    "tier": gpu_tier_from_name(parts[0]),
                })
        return {"available": True, "gpus": gpus, "gpu_count": len(gpus)}
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        return {"available": False, "reason": str(exc)}
