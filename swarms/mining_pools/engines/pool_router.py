"""Mining pool router — helical handoff from physical-core ASIC telemetry."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ingest_physical_core(snapshot_path: Path | None = None) -> dict[str, Any]:
    path = snapshot_path or Path(".data/physical-core/latest.json")
    aggregate_gh = 0.0
    message_id = None
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
        aggregate_gh = float(data.get("asics", {}).get("aggregateHashrateGh", 0))
        message_id = data.get("capturedAt")

    estimated_usd = round(aggregate_gh * 0.012, 2)
    split = [0.5, 0.3, 0.15, 0.05]
    return {
        "schemaVersion": "mining-pools/v1",
        "capturedAt": _utc_now(),
        "siteId": "carrizozo-nm-10ac",
        "pools": [
            {
                "poolId": "equihash-primary",
                "algorithm": "equihash",
                "coin": "ZEC",
                "status": "active" if aggregate_gh > 0 else "standby",
                "hashrate": aggregate_gh,
                "hashrateUnit": "GH/s",
                "workersOnline": 30 if aggregate_gh > 0 else 0,
                "payoutAddress": "vault-managed",
            }
        ],
        "attribution": {
            "treasurySplit": "50,30,15,5",
            "estimatedUsd24h": estimated_usd,
            "coreTreasuryUsd": round(estimated_usd * split[0], 2),
            "growthTreasuryUsd": round(estimated_usd * split[1], 2),
            "insuranceTreasuryUsd": round(estimated_usd * split[2], 2),
            "opsTreasuryUsd": round(estimated_usd * split[3], 2),
        },
        "physicalCoreRef": {
            "messageId": message_id,
            "aggregateHashrateGh": aggregate_gh,
        },
    }
