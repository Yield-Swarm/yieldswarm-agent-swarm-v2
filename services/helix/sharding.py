"""Helix Chain A+1 parallel layer sharding."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[2]


class HelixSharding:
    """A+1 model: Ancestral audit layer + N parallel execution shards."""

    def __init__(self, shard_count: int | None = None):
        self.shard_count = shard_count or int(os.environ.get("CRON_SHARD_COUNT", "120"))
        self.ancestral_blocks = int(os.environ.get("HELIX_ANCESTRAL_BLOCKS", "64"))

    def layer_topology(self) -> Dict[str, Any]:
        return {
            "model": "A+1",
            "ancestral_layer": {
                "blocks": self.ancestral_blocks,
                "role": "hardened_audit_chain",
            },
            "parallel_layers": self.shard_count,
            "formula": "shard_id = coordinate % shard_count",
        }

    def route_shard(self, coordinate: int) -> int:
        return coordinate % self.shard_count

    def helix_state(self) -> Dict[str, Any]:
        path = REPO_ROOT / "dashboard" / "helix-state.json"
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return {"activated": False, "phase": "genesis", "readinessScore": 0}

    def snapshot(self) -> Dict[str, Any]:
        state = self.helix_state()
        return {
            "topology": self.layer_topology(),
            "helix": state,
            "yslr_phase": state.get("yslr_phase", os.environ.get("YSLR_PHASE", "genesis")),
        }
