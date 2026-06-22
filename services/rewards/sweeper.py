"""Sweep assembled reward batches to on-chain / mining root wallets."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from mining.rewards import RewardRouter
from services.rewards.manifest import rewards_dry_run

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_DIR = REPO_ROOT / ".run"
ASSEMBLE_FILE = RUN_DIR / "rewards-assemble.json"


class RewardSweeper:
    """Route assembled batches through RewardRouter + Great Delta covenant."""

    def __init__(self) -> None:
        self.router = RewardRouter()
        self.dry_run = rewards_dry_run()

    def sweep(self, assembled: dict[str, Any] | None = None) -> dict[str, Any]:
        if assembled is None:
            if not ASSEMBLE_FILE.is_file():
                return {"ok": False, "error": "run assemble first — missing .run/rewards-assemble.json"}
            assembled = json.loads(ASSEMBLE_FILE.read_text(encoding="utf-8"))

        receipts: list[dict[str, Any]] = []
        for batch in assembled.get("batches") or []:
            wallet = batch["wallet"]
            amount = float(batch["amount_usd"])
            coin = self._infer_coin(batch.get("root_keys") or [])
            receipt = self.router.route_mining_revenue(
                amount,
                source="rewards_sweep",
                coin=coin,
                apply_treasury_split=True,
            )
            receipt["wallet"] = wallet
            receipt["batch_shard_ids"] = batch.get("shard_ids", [])
            receipt["status"] = "simulated" if self.dry_run else "submitted"
            receipt["tx_hash"] = None if self.dry_run else f"pending-{wallet[:8]}"
            receipts.append(receipt)

        out = {
            "ok": True,
            "phase": "sweep",
            "dry_run": self.dry_run,
            "swept_at": datetime.now(timezone.utc).isoformat(),
            "receipt_count": len(receipts),
            "total_usd": round(sum(float(r.get("amount_usd") or 0) for r in receipts), 8),
            "receipts": receipts,
            "route_table": self.router.route_table(),
        }
        RUN_DIR.mkdir(parents=True, exist_ok=True)
        (RUN_DIR / "rewards-sweep.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
        return out

    @staticmethod
    def _infer_coin(root_keys: list[str]) -> str:
        if not root_keys:
            return "sol"
        key = root_keys[0].lower()
        mapping = {
            "tao": "tao",
            "nexus_solana": "sol",
            "iotex": "iotex",
            "btc_via_iopay": "btc",
            "base_btc": "btc",
            "zec": "zec",
            "base_etc": "etc",
            "prl": "sol",
        }
        return mapping.get(key, "sol")
