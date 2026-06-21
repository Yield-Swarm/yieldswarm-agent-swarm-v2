"""Bittensor (TAO) miner — uses funded wallet from env/Vault."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from mining.config import MiningConfig
from mining.miners.base import BaseMiner

REPO_ROOT = Path(__file__).resolve().parents[2]


class BittensorMiner(BaseMiner):
    name = "bittensor"

    def validate(self) -> Optional[str]:
        if not self.config.tao_wallet and not os.getenv("BT_NETUID"):
            return "MINING_ROOT_TAO or BT_NETUID required"
        if not os.getenv("BT_NETUID") and self.config.bt_netuid <= 0:
            return "BT_NETUID required"
        return None

    def _wallet_display(self) -> str:
        return self.config.tao_wallet or self.config.tao_hotkey or "vault:runtime/bittensor"

    def build_config(self) -> Dict[str, Any]:
        return {
            "miner": "bittensor",
            "netuid": self.config.bt_netuid,
            "network": self.config.bt_network,
            "wallet_name": self.config.bt_wallet_name,
            "hotkey_name": self.config.bt_hotkey_name,
            "axon_port": self.config.bt_axon_port,
            "ollama_model": self.config.ollama_model,
            "coldkey_address": self.config.tao_wallet,
            "hotkey_address": self.config.tao_hotkey,
            "agent_script": str(REPO_ROOT / "agents" / "bittensor_miner.py"),
            "deploy_sdl": str(REPO_ROOT / "deploy" / "akash-bittensor-miner.sdl.yml"),
        }

    def start_command(self) -> List[str]:
        env = os.environ.copy()
        env.setdefault("BT_NETUID", str(self.config.bt_netuid))
        env.setdefault("BT_NETWORK", self.config.bt_network)
        env.setdefault("BT_AXON_PORT", str(self.config.bt_axon_port))
        env.setdefault("OLLAMA_MODEL", self.config.ollama_model)
        os.environ.update(env)
        return [sys.executable, str(REPO_ROOT / "agents" / "bittensor_miner.py")]
