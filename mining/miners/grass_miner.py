"""Grass DePIN nodes with lineup multipliers (Android 3x, desktop 2x)."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Optional

from mining.miners.base import BaseMiner, MinerState, MinerStatus


class GrassMiner(BaseMiner):
    name = "grass"

    def validate(self) -> Optional[str]:
        if not self.config.grass_lineups:
            return "GRASS_NODE_KEYS or GRASS_LINEUPS required"
        missing = [lu.id for lu in self.config.grass_lineups if not lu.wallet]
        if missing:
            return f"Grass lineups missing wallet: {', '.join(missing)}"
        return None

    def _wallet_display(self) -> str:
        wallets = [lu.wallet for lu in self.config.grass_lineups if lu.wallet]
        return wallets[0] if len(wallets) == 1 else f"{len(wallets)} lineups"

    def build_config(self) -> Dict[str, Any]:
        total_multiplier = sum(lu.multiplier for lu in self.config.grass_lineups)
        return {
            "miner": "grass",
            "api_base": self.config.grass_api_base,
            "lineups": [lu.to_dict() for lu in self.config.grass_lineups],
            "total_effective_multiplier": round(total_multiplier, 2),
            "sybil_rules": {
                "one_account_per_ip_subnet": True,
                "android_on_separate_mobile_data": True,
            },
            "platform_multipliers": {
                "android": 3.0,
                "linux": 2.0,
                "windows": 2.0,
                "mac": 2.0,
            },
        }

    def start_command(self) -> List[str]:
        # Grass desktop daemon / extension supervisor stub
        return [
            sys.executable,
            "-c",
            (
                "import json,time; "
                f"cfg=json.load(open({json.dumps(str(self.config_file))})); "
                "print('[grass] lineups active:', len(cfg.get('lineups',[])), "
                "'multiplier=', cfg.get('total_effective_multiplier')); "
                "import time; "
                "while True: time.sleep(300)"
            ),
        ]

    def status(self) -> MinerStatus:
        base = super().status()
        cfg = self.build_config() if self.config_file.exists() else {}
        if not cfg and self.config.grass_lineups:
            cfg = self.build_config()
        base.metrics = {
            "lineup_count": len(self.config.grass_lineups),
            "total_multiplier": cfg.get("total_effective_multiplier", 0),
            "lineups": [lu.id for lu in self.config.grass_lineups],
        }
        return base
