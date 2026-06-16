"""Unified multi-cloud telemetry aggregator."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


class UnifiedTelemetry:
    """Aggregates worker metrics for Great Delta rebalancing."""

    def __init__(self, path: Optional[Path] = None):
        self.path = path or (_run_dir() / "cloud-telemetry.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def _read(self) -> Dict[str, Any]:
        if not self.path.exists():
            return {"workers": [], "providers": {}, "updated_at": 0}
        try:
            return json.loads(self.path.read_text())
        except json.JSONDecodeError:
            return {"workers": [], "providers": {}, "updated_at": 0}

    def _write(self, data: Dict[str, Any]) -> None:
        data["updated_at"] = int(time.time())
        self.path.write_text(json.dumps(data, indent=2))

    def ingest_worker(
        self,
        worker_id: str,
        provider: str,
        metrics: Dict[str, Any],
    ) -> None:
        data = self._read()
        workers: List[Dict[str, Any]] = data.setdefault("workers", [])
        entry = {
            "worker_id": worker_id,
            "provider": provider,
            "metrics": metrics,
            "ts": int(time.time()),
        }
        workers.append(entry)
        # Keep last 500 samples
        data["workers"] = workers[-500:]
        prov = data.setdefault("providers", {}).setdefault(provider, {})
        prov["last_seen"] = int(time.time())
        prov["sample_count"] = prov.get("sample_count", 0) + 1
        if "hashrate" in metrics:
            prov["hashrate"] = metrics["hashrate"]
        if "earnings_usd" in metrics:
            prov["earnings_usd"] = prov.get("earnings_usd", 0.0) + float(metrics["earnings_usd"])
        if "credit_burn_usd" in metrics:
            prov["credit_burn_usd"] = prov.get("credit_burn_usd", 0.0) + float(metrics["credit_burn_usd"])
        if "temperature_c" in metrics:
            prov["temperature_c"] = metrics["temperature_c"]
        self._write(data)

    def provider_summary(self) -> Dict[str, Dict[str, Any]]:
        data = self._read()
        return data.get("providers", {})

    def to_great_delta_input(self) -> Dict[str, float]:
        """Map provider earnings to treasury rebalance buckets (scaffold)."""
        summary = self.provider_summary()
        total_revenue = sum(float(p.get("earnings_usd", 0)) for p in summary.values())
        total_burn = sum(float(p.get("credit_burn_usd", 0)) for p in summary.values())
        return {
            "gross_revenue_usd": total_revenue,
            "credit_burn_usd": total_burn,
            "net_usd": total_revenue - total_burn,
        }

    def snapshot(self) -> Dict[str, Any]:
        data = self._read()
        data["great_delta"] = self.to_great_delta_input()
        return data
