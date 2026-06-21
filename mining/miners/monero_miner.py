"""Monero (XMR) mining config — xmrig pool + wallet from env."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from mining.miners.base import BaseMiner


class MoneroMiner(BaseMiner):
    name = "monero"

    def validate(self) -> Optional[str]:
        if not self.config.monero_wallet:
            return "MONERO_WALLET_ADDRESS or MINING_ROOT_MONERO required"
        return None

    def _wallet_display(self) -> str:
        return self.config.monero_wallet

    def build_config(self) -> Dict[str, Any]:
        pool = self.config.monero_pool
        return {
            "miner": "xmrig",
            "autosave": True,
            "cpu": True,
            "opencl": False,
            "cuda": False,
            "pools": [
                {
                    "url": pool.url,
                    "user": pool.user or self.config.monero_wallet,
                    "pass": pool.password,
                    "tls": True,
                    "keepalive": True,
                }
            ],
            "donate-level": 1,
            "print-time": 60,
            "retries": 5,
            "retry-pause": 5,
        }

    def start_command(self) -> List[str]:
        return [
            self.config.xmrig_path,
            "--config",
            str(self.config_file),
            "--url",
            self.config.monero_pool.url,
            "--user",
            self.config.monero_pool.user or self.config.monero_wallet,
            "--pass",
            self.config.monero_pool.password,
            "--tls",
        ]
