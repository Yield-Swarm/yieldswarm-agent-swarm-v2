"""Emit signed Kairo telemetry into YieldSwarm shard harvest files."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class YieldSwarmEmitter:
    """Write harvest JSON consumed by YieldSwarm agent shard crons."""

    def __init__(self, harvest_dir: Path | None = None) -> None:
        default = Path(os.environ.get("YIELDSWARM_HARVEST_DIR", ".data/yieldswarm/harvest"))
        self.harvest_dir = harvest_dir or default
        self.harvest_dir.mkdir(parents=True, exist_ok=True)

    def emit(self, record: dict[str, Any]) -> str:
        tree = record.get("tree", {})
        shard_id = int(tree.get("shard_id", 0))
        shard_dir = self.harvest_dir / f"shard-{shard_id:03d}"
        shard_dir.mkdir(parents=True, exist_ok=True)

        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        path = shard_dir / f"kairo-{record.get('telemetry_id', ts)}.json"

        envelope = {
            "source": "kairo-telemetry",
            "emitted_at": datetime.now(timezone.utc).isoformat(),
            "shard_id": shard_id,
            "driver_id": record.get("driver_id"),
            "evm_address": record.get("evm_address"),
            "reward_weight": tree.get("reward_weight"),
            "mandelbrot_score": tree.get("mandelbrot_score"),
            "tree": tree,
            "payload": record.get("payload"),
            "signature": record.get("signature"),
        }
        path.write_text(json.dumps(envelope, indent=2), encoding="utf-8")
        return str(path)
