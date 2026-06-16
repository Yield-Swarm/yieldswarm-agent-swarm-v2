"""Multi-cloud provider registry and launch helpers."""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

# Priority order: revenue-first
PROVIDER_PRIORITY = ("akash", "vast", "runpod", "azure", "gcp", "aws", "alibaba")

WORKLOAD_DEFAULTS: Dict[str, Dict[str, Any]] = {
    "bittensor": {
        "providers": ["akash", "vast"],
        "gpu": "RTX_3090",
        "revenue_weight": 1.0,
    },
    "inference": {
        "providers": ["akash", "runpod", "vast"],
        "gpu": "RTX_4090",
        "revenue_weight": 0.8,
    },
    "training": {
        "providers": ["vast", "runpod", "gcp"],
        "gpu": "RTX_4090",
        "revenue_weight": 0.6,
    },
    "grass": {
        "providers": ["azure", "gcp", "aws"],
        "gpu": "none",
        "revenue_weight": 0.5,
    },
    "cpu_batch": {
        "providers": ["azure", "aws", "alibaba"],
        "gpu": "none",
        "revenue_weight": 0.3,
    },
}


@dataclass
class ProviderState:
    name: str
    active_jobs: int = 0
    daily_spend_usd: float = 0.0
    daily_revenue_usd: float = 0.0
    healthy: bool = True

    @property
    def roi(self) -> float:
        if self.daily_spend_usd <= 0:
            return self.daily_revenue_usd
        return self.daily_revenue_usd / self.daily_spend_usd


def provider_budget_cap(name: str) -> float:
    key = f"MULTICLOUD_{name.upper()}_MAX_USD"
    defaults = {
        "AKASH": float(os.getenv("MULTICLOUD_AKASH_MAX_AKT", "5")) * 2,
        "VAST": 150.0,
        "RUNPOD": 200.0,
        "AZURE": 300.0,
        "GCP": 300.0,
        "AWS": 200.0,
        "ALIBABA": 100.0,
    }
    raw = os.getenv(key, str(defaults.get(name.upper(), 50)))
    try:
        return float(raw)
    except ValueError:
        return 50.0


def launch_workload(
    provider: str,
    workload: str,
    params: Optional[Dict[str, Any]] = None,
    *,
    dry_run: bool = True,
) -> Dict[str, Any]:
    """Launch via multicloud script or internal dry-run."""
    params = params or {}
    script = os.path.join(
        os.path.dirname(__file__), "..", "..", "scripts", "multicloud", "launch-worker.sh"
    )
    env = {
        **os.environ,
        "PROVIDER": provider,
        "WORKLOAD": workload,
        "DRY_RUN": "1" if dry_run else "0",
        "GPU": params.get("gpu", WORKLOAD_DEFAULTS.get(workload, {}).get("gpu", "RTX_3090")),
    }
    if os.path.isfile(script):
        proc = subprocess.run(
            ["bash", script],
            env=env,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        return {
            "provider": provider,
            "workload": workload,
            "dry_run": dry_run,
            "exit_code": proc.returncode,
            "stdout": proc.stdout[-2000:] if proc.stdout else "",
            "stderr": proc.stderr[-500:] if proc.stderr else "",
        }
    return {
        "provider": provider,
        "workload": workload,
        "dry_run": dry_run,
        "simulated": True,
        "note": "multicloud launch script not present — simulated launch",
    }


def best_provider_for_workload(
    workload: str,
    states: Dict[str, ProviderState],
) -> Optional[str]:
    spec = WORKLOAD_DEFAULTS.get(workload, {})
    candidates: List[str] = list(spec.get("providers", list(PROVIDER_PRIORITY)))
    revenue_weight = float(spec.get("revenue_weight", 0.5))

    scored = []
    for name in candidates:
        st = states.get(name, ProviderState(name=name))
        if not st.healthy:
            continue
        if st.daily_spend_usd >= provider_budget_cap(name):
            continue
        score = st.roi * revenue_weight - (st.active_jobs * 0.1)
        scored.append((score, name))
    if not scored:
        return candidates[0] if candidates else None
    scored.sort(reverse=True)
    return scored[0][1]
