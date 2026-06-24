"""Kaspa (kHeavyHash) miner — enterprise GPU tier."""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from mining.miners.base import BaseMiner


class KaspaMiner(BaseMiner):
    name = "kaspa"

    def validate(self) -> Optional[str]:
        wallet = os.getenv("KASPA_WALLET_ADDRESS") or os.getenv("KAS_WALLET_ADDRESS")
        if not wallet:
            return "KASPA_WALLET_ADDRESS or KAS_WALLET_ADDRESS required"
        return None

    def _wallet_display(self) -> str:
        return os.getenv("KASPA_WALLET_ADDRESS") or os.getenv("KAS_WALLET_ADDRESS") or ""

    def build_config(self) -> Dict[str, Any]:
        pool = os.getenv("KASPA_POOL_URL", "kas.auto.nicehash.com:3385")
        worker = os.getenv("KASPA_WORKER_NAME", "yieldswarm")
        return {
            "algorithm": "kheavyhash",
            "pool": pool,
            "wallet": self._wallet_display(),
            "worker": worker,
            "miner_binary": os.getenv("SRBMINER_PATH", "SRBMiner-MULTI"),
        }

    def start_command(self) -> List[str]:
        cfg = self.build_config()
        binary = cfg["miner_binary"]
        return [
            binary,
            "--algorithm", "kheavyhash",
            "--pool", cfg["pool"],
            "--wallet", f"{cfg['wallet']}.{cfg['worker']}",
        ]
