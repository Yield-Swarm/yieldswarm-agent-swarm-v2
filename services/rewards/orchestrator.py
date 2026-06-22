"""Rewards orchestrator — reshard → assemble → sweep pipeline."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from services.rewards.assembler import RewardAssembler
from services.rewards.manifest import mining_root_wallets, rewards_dry_run
from services.rewards.resharder import RewardResharder
from services.rewards.sweeper import RewardSweeper

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_DIR = REPO_ROOT / ".run"


class RewardsOrchestrator:
    def __init__(self) -> None:
        self.resharder = RewardResharder()
        self.assembler = RewardAssembler()
        self.sweeper = RewardSweeper()

    def status(self) -> dict[str, Any]:
        roots = mining_root_wallets()
        phases = {}
        for name, path in (
            ("reshard", RUN_DIR / "rewards-reshard.json"),
            ("assemble", RUN_DIR / "rewards-assemble.json"),
            ("sweep", RUN_DIR / "rewards-sweep.json"),
        ):
            if path.is_file():
                phases[name] = json.loads(path.read_text(encoding="utf-8"))
            else:
                phases[name] = None

        return {
            "live": True,
            "strand": "rewards",
            "dry_run": rewards_dry_run(),
            "mining_roots": roots,
            "root_count": len(roots),
            "great_delta": "50/30/15/5",
            "phases": phases,
            "pending_gross_usd": self.resharder._pending_gross_usd(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

    def run_full(self) -> dict[str, Any]:
        reshard = self.resharder.reshard()
        if not reshard.get("ok"):
            return reshard
        assembled = self.assembler.assemble(reshard)
        if not assembled.get("ok"):
            return assembled
        sweep = self.sweeper.sweep(assembled)
        return {
            "ok": sweep.get("ok", False),
            "phase": "full",
            "dry_run": rewards_dry_run(),
            "reshard": reshard,
            "assemble": assembled,
            "sweep": sweep,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }
