"""Assemble resharded shards into per-wallet sweep batches."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_DIR = REPO_ROOT / ".run"
RESHARD_FILE = RUN_DIR / "rewards-reshard.json"


class RewardAssembler:
    """Group shards by destination wallet for batched settlement."""

    def assemble(self, reshard: dict[str, Any] | None = None) -> dict[str, Any]:
        if reshard is None:
            if not RESHARD_FILE.is_file():
                return {"ok": False, "error": "run reshard first — missing .run/rewards-reshard.json"}
            reshard = json.loads(RESHARD_FILE.read_text(encoding="utf-8"))

        batches: dict[str, dict[str, Any]] = defaultdict(
            lambda: {"wallet": "", "root_keys": [], "shard_ids": [], "amount_usd": 0.0}
        )

        for shard in reshard.get("shards") or []:
            wallet = shard["wallet"]
            batch = batches[wallet]
            batch["wallet"] = wallet
            batch["root_keys"].append(shard["root_key"])
            batch["shard_ids"].append(shard["shard_id"])
            batch["amount_usd"] = round(batch["amount_usd"] + float(shard["amount_usd"]), 8)

        assembled = list(batches.values())
        out = {
            "ok": True,
            "phase": "assemble",
            "batch_count": len(assembled),
            "total_usd": round(sum(b["amount_usd"] for b in assembled), 8),
            "batches": assembled,
            "treasury_split": reshard.get("treasury_split"),
        }
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        (RUN_DIR / "rewards-assemble.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
        return out
