"""Mining wallet + pool configuration from environment."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


def _normalize_node_list(items: List[Any]) -> List[Dict[str, Any]]:
    normalized: List[Dict[str, Any]] = []
    for i, item in enumerate(items):
        if isinstance(item, dict):
            normalized.append(item)
        elif isinstance(item, str):
            normalized.append({"id": f"node-{i + 1}", "wallet": item, "platform": "linux"})
        else:
            normalized.append({"id": f"node-{i + 1}", "wallet": str(item)})
    return normalized


def _json_list(value: str) -> List[Dict[str, Any]]:
    if not value or value.strip() in ("", "[]", "[REDACTED]"):
        return []
    try:
        parsed = json.loads(value)
        if isinstance(parsed, list):
            return _normalize_node_list(parsed)
        if isinstance(parsed, dict):
            return [parsed]
        return []
    except json.JSONDecodeError:
        return []


def _json_obj(value: str) -> Dict[str, Any]:
    if not value or value.strip() in ("", "{}", "[REDACTED]"):
        return {}
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


@dataclass
class PoolConfig:
    url: str
    user: str
    password: str = "x"
    algorithm: str = ""


@dataclass
class GrassLineup:
    id: str
    platform: str
    multiplier: float
    wallet: str
    device_id: str = ""
    network: str = "residential"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "platform": self.platform,
            "multiplier": self.multiplier,
            "wallet": self.wallet,
            "device_id": self.device_id,
            "network": self.network,
        }


@dataclass
class HeliumHotspot:
    model: str = ""
    serial: str = ""
    mac: str = ""
    ssid: str = ""
    setup_password: str = ""
    wallet: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "model": self.model,
            "serial": self.serial,
            "mac": self.mac,
            "ssid": self.ssid,
            "wallet": self.wallet,
            "setup_password_configured": bool(self.setup_password),
        }


@dataclass
class MiningConfig:
    """All mining payout wallets and operator settings."""

    run_dir: str = ".run/mining"
    dry_run: bool = True
    execution_capacity: float = 0.80

    # Wallets (public addresses — keys stay in Vault)
    tao_wallet: str = ""
    tao_hotkey: str = ""
    monero_wallet: str = ""
    etc_wallet: str = ""

    # Bittensor
    bt_netuid: int = 1
    bt_network: str = "finney"
    bt_wallet_name: str = "miner"
    bt_hotkey_name: str = "default"
    bt_axon_port: int = 8091
    ollama_model: str = "llama3.1:8b"

    # Monero
    monero_pool: PoolConfig = field(default_factory=lambda: PoolConfig(url="", user=""))
    xmrig_path: str = "xmrig"

    # Ethereum Classic
    etc_pool: PoolConfig = field(default_factory=lambda: PoolConfig(url="", user=""))
    etc_miner: str = "lolMiner"  # lolMiner | t-rex | phoenix

    # Grass lineups
    grass_lineups: List[GrassLineup] = field(default_factory=list)
    grass_api_base: str = "https://api.getgrass.io"

    # Helium
    helium_hotspots: List[HeliumHotspot] = field(default_factory=list)

    def redacted(self) -> Dict[str, Any]:
        return {
            "dry_run": self.dry_run,
            "execution_capacity": self.execution_capacity,
            "tao_wallet": self.tao_wallet,
            "tao_hotkey": self.tao_hotkey,
            "monero_wallet": self.monero_wallet,
            "etc_wallet": self.etc_wallet,
            "bt_netuid": self.bt_netuid,
            "bt_network": self.bt_network,
            "grass_lineup_count": len(self.grass_lineups),
            "helium_hotspot_count": len(self.helium_hotspots),
        }


def load_mining_config() -> MiningConfig:
    tao_wallet = (
        os.getenv("MINING_ROOT_TAO")
        or os.getenv("BITTENSOR_COLDKEY_ADDRESS")
        or os.getenv("TAO_WALLET_ADDRESS")
        or ""
    )
    monero_wallet = (
        os.getenv("MONERO_WALLET_ADDRESS")
        or os.getenv("MINING_ROOT_MONERO")
        or os.getenv("XMR_WALLET_ADDRESS")
        or ""
    )
    etc_wallet = (
        os.getenv("MINING_ROOT_BASE_ETC")
        or os.getenv("ETC_WALLET_ADDRESS")
        or ""
    )

    grass_keys = _json_list(os.getenv("GRASS_NODE_KEYS", "[]"))
    lineups_raw = _json_obj(os.getenv("GRASS_LINEUPS", "{}"))
    grass_lineups: List[GrassLineup] = []

    if lineups_raw.get("lineups"):
        for i, row in enumerate(lineups_raw["lineups"]):
            grass_lineups.append(
                GrassLineup(
                    id=row.get("id", f"lineup-{i + 1}"),
                    platform=row.get("platform", "linux"),
                    multiplier=float(row.get("multiplier", 2)),
                    wallet=row.get("wallet", ""),
                    device_id=row.get("device_id", ""),
                    network=row.get("network", "residential"),
                )
            )
    else:
        # Build lineups from GRASS_NODE_KEYS with platform multipliers
        platform_mult = {"android": 3.0, "linux": 2.0, "windows": 2.0, "mac": 2.0, "darwin": 2.0}
        for i, node in enumerate(grass_keys):
            platform = str(node.get("platform", "linux")).lower()
            grass_lineups.append(
                GrassLineup(
                    id=node.get("id", f"grass-{i + 1}"),
                    platform=platform,
                    multiplier=float(node.get("multiplier", platform_mult.get(platform, 1.0))),
                    wallet=node.get("wallet", node.get("address", "")),
                    device_id=node.get("device_id", ""),
                    network=node.get("network", "residential"),
                )
            )

    helium_hotspots: List[HeliumHotspot] = []
    for row in _json_list(os.getenv("DEPIN_HELIUM_HOTSPOT_KEYS", "[]")):
        helium_hotspots.append(
            HeliumHotspot(
                model=row.get("model", ""),
                serial=row.get("serial", ""),
                mac=row.get("mac", ""),
                ssid=row.get("ssid", ""),
                setup_password=row.get("setup_password", row.get("wifi_password", "")),
                wallet=row.get("wallet", row.get("payout_address", "")),
            )
        )

    monero_pool = PoolConfig(
        url=os.getenv("MONERO_POOL_URL", "pool.supportxmr.com:443"),
        user=monero_wallet or os.getenv("MONERO_POOL_USER", ""),
        password=os.getenv("MONERO_POOL_PASSWORD", "x"),
        algorithm="rx/0",
    )

    etc_pool = PoolConfig(
        url=os.getenv("ETC_POOL_URL", "etc.2miners.com:1010"),
        user=etc_wallet or os.getenv("ETC_POOL_USER", ""),
        password=os.getenv("ETC_POOL_PASSWORD", "x"),
        algorithm="etchash",
    )

    dry_run = os.getenv("MINING_DRY_RUN", os.getenv("CROSS_CHAIN_DRY_RUN", "1")).lower() in (
        "1",
        "true",
        "yes",
    )

    try:
        execution_capacity = float(os.getenv("EXECUTION_CAPACITY", "0.80"))
    except ValueError:
        execution_capacity = 0.80
    execution_capacity = max(0.1, min(1.0, execution_capacity))

    return MiningConfig(
        run_dir=os.getenv("MINING_RUN_DIR", ".run/mining"),
        dry_run=dry_run,
        execution_capacity=execution_capacity,
        tao_wallet=tao_wallet,
        tao_hotkey=os.getenv("BITTENSOR_HOTKEY_ADDRESS", ""),
        monero_wallet=monero_wallet,
        etc_wallet=etc_wallet,
        bt_netuid=int(os.getenv("BT_NETUID", "1")),
        bt_network=os.getenv("BT_NETWORK", "finney"),
        bt_wallet_name=os.getenv("BT_WALLET_NAME", "miner"),
        bt_hotkey_name=os.getenv("BT_HOTKEY_NAME", "default"),
        bt_axon_port=int(os.getenv("BT_AXON_PORT", "8091")),
        ollama_model=os.getenv("OLLAMA_MODEL", "llama3.1:8b"),
        monero_pool=monero_pool,
        xmrig_path=os.getenv("XMRIG_PATH", "xmrig"),
        etc_pool=etc_pool,
        etc_miner=os.getenv("ETC_MINER_BINARY", "lolMiner"),
        grass_lineups=grass_lineups,
        grass_api_base=os.getenv("GRASS_API_BASE", "https://api.getgrass.io").rstrip("/"),
        helium_hotspots=helium_hotspots,
    )
