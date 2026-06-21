"""Ethereum Classic (ETC) mining — lolMiner / compatible pool config."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from mining.miners.base import BaseMiner


class EthereumClassicMiner(BaseMiner):
    name = "etc"

    def validate(self) -> Optional[str]:
        if not self.config.etc_wallet:
            return "MINING_ROOT_BASE_ETC or ETC_WALLET_ADDRESS required"
        if not self.config.etc_wallet.startswith("0x"):
            return "ETC wallet must be EVM address (0x...)"
        return None

    def _wallet_display(self) -> str:
        return self.config.etc_wallet

    def build_config(self) -> Dict[str, Any]:
        pool = self.config.etc_pool
        return {
            "miner": self.config.etc_miner,
            "coin": "ETC",
            "algorithm": "ETCHASH",
            "pool": {
                "url": pool.url,
                "user": pool.user or self.config.etc_wallet,
                "password": pool.password,
            },
            "wallet": self.config.etc_wallet,
        }

    def start_command(self) -> List[str]:
        wallet = self.config.etc_pool.user or self.config.etc_wallet
        miner = self.config.etc_miner.lower()
        pool_url = self.config.etc_pool.url

        if "lolminer" in miner:
            return [
                self.config.etc_miner,
                "--coin",
                "ETC",
                "--pool",
                pool_url,
                "--user",
                wallet,
                "--pass",
                self.config.etc_pool.password,
            ]
        # t-rex / generic ethash fallback
        return [
            self.config.etc_miner,
            "-a",
            "etchash",
            "-o",
            pool_url,
            "-u",
            wallet,
            "-p",
            self.config.etc_pool.password,
        ]
