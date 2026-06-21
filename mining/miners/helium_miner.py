"""Helium hotspot deployment and monitoring."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Optional

from pathlib import Path

from mining.miners.base import BaseMiner, MinerState, MinerStatus

REPO_ROOT = Path(__file__).resolve().parents[2]


class HeliumMiner(BaseMiner):
    name = "helium"

    def validate(self) -> Optional[str]:
        if not self.config.helium_hotspots:
            return "DEPIN_HELIUM_HOTSPOT_KEYS required (JSON array)"
        return None

    def _wallet_display(self) -> str:
        wallets = [h.wallet for h in self.config.helium_hotspots if h.wallet]
        return wallets[0] if wallets else f"{len(self.config.helium_hotspots)} hotspots"

    def build_config(self) -> Dict[str, Any]:
        return {
            "miner": "helium",
            "hotspots": [h.to_dict() for h in self.config.helium_hotspots],
            "deploy_script": "scripts/mining/deploy-helium-hotspot.sh",
            "setup_flow": [
                "Connect to hotspot WiFi (SSID from config)",
                "Open setup portal (192.168.4.1 or auto-redirect)",
                "Link serial to Helium account",
                "Configure backhaul (home WiFi / Ethernet)",
            ],
        }

    def start_command(self) -> List[str]:
        deploy_script = REPO_ROOT / "scripts" / "mining" / "deploy-helium-hotspot.sh"
        if deploy_script.exists():
            return ["/bin/bash", str(deploy_script), "--config", str(self.config_file)]
        return [
            sys.executable,
            "-c",
            (
                "import json,time; "
                f"cfg=json.load(open({json.dumps(str(self.config_file))})); "
                "print('[helium] monitoring', len(cfg.get('hotspots',[])), 'hotspot(s)'); "
                "while True: time.sleep(600)"
            ),
        ]

    def status(self) -> MinerStatus:
        base = super().status()
        base.metrics = {
            "hotspot_count": len(self.config.helium_hotspots),
            "serials": [h.serial for h in self.config.helium_hotspots if h.serial],
            "ssids": [h.ssid for h in self.config.helium_hotspots if h.ssid],
        }
        return base
