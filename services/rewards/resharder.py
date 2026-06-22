"""Reshard pending revenue across mining roots and Great Delta buckets."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from agents.governance.gospel import TREASURY_SPLIT_BPS
from services.cross_chain.great_delta import route_revenue_to_treasury
from services.rewards.manifest import mining_root_wallets

REPO_ROOT = Path(__file__).resolve().parents[2]
STATE_PATH = REPO_ROOT / "dashboard" / "state.json"
RUN_DIR = REPO_ROOT / ".run"


class RewardResharder:
    """Split gross pending USD into per-root shards weighted by manifest keys."""

    def __init__(self, shard_count: int | None = None):
        self.shard_count = shard_count or int(os.environ.get("REWARDS_SHARD_COUNT", "120"))

    def _pending_gross_usd(self) -> float:
        if os.environ.get("REWARDS_PENDING_USD"):
            return float(os.environ["REWARDS_PENDING_USD"])
        if STATE_PATH.is_file():
            state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
            hourly = float(state.get("fleet_net_hourly_usd") or 0)
            return round(hourly * 24, 4)
        return 0.0

    def reshard(self) -> dict[str, Any]:
        gross = self._pending_gross_usd()
        roots = mining_root_wallets()
        if not roots:
            return {"ok": False, "error": "no mining roots in TREASURY_MANIFEST.json"}

        treasury_split = route_revenue_to_treasury(gross, source="rewards_reshard", strategy="multi_root")
        root_keys = list(roots.keys())
        per_root = gross / len(root_keys) if root_keys else 0.0

        shards: list[dict[str, Any]] = []
        for i in range(self.shard_count):
            root_key = root_keys[i % len(root_keys)]
            shards.append(
                {
                    "shard_id": i,
                    "root_key": root_key,
                    "wallet": roots[root_key],
                    "amount_usd": round(per_root / (self.shard_count / len(root_keys)), 8),
                    "bps_lane": TREASURY_SPLIT_BPS[i % len(TREASURY_SPLIT_BPS)],
                }
            )

        out = {
            "ok": True,
            "phase": "reshard",
            "gross_usd": gross,
            "shard_count": len(shards),
            "root_count": len(root_keys),
            "treasury_split": treasury_split,
            "shards": shards,
        }
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        (RUN_DIR / "rewards-reshard.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
        return out
