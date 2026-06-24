"""Qubic GPU compute lease miner — H100/H200/B200 tier."""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from mining.miners.base import BaseMiner


class QubicMiner(BaseMiner):
    name = "qubic"

    def validate(self) -> Optional[str]:
        wallet = os.getenv("QUBIC_WALLET_ADDRESS") or os.getenv("QUBIC_WALLET")
        if not wallet:
            return "QUBIC_WALLET_ADDRESS required (60-char Qubic address)"
        if len(wallet) < 55:
            return "QUBIC wallet appears invalid length"
        return None

    def _wallet_display(self) -> str:
        return os.getenv("QUBIC_WALLET_ADDRESS") or os.getenv("QUBIC_WALLET") or ""

    def build_config(self) -> Dict[str, Any]:
        return {
            "wallet": self._wallet_display(),
            "pool": os.getenv("QUBIC_POOL_URL", "https://rpc.qubic.org"),
            "miner_binary": os.getenv("QUBIC_MINER_PATH", "qubic-cli"),
            "capacity": float(os.getenv("EXECUTION_CAPACITY", "0.80")),
        }

    def start_command(self) -> List[str]:
        cfg = self.build_config()
        binary = cfg["miner_binary"]
        # Placeholder — real qubic miner argv varies by release
        return [binary, "mine", "--wallet", cfg["wallet"]]
