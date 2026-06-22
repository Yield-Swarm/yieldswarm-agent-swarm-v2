"""Load Christopher's First App Alchemy network manifest (no API keys)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO_ROOT / "config" / "alchemy" / "christophers-first-app.json"


@dataclass(frozen=True)
class AlchemyNetwork:
    id: str
    name: str
    host: str
    family: str
    chain_id: Optional[int] = None
    url_pattern: str = "v2"
    enabled: bool = True

    def build_url(self, api_key: str) -> str:
        key = api_key.strip()
        if self.url_pattern == "starknet_v0_10":
            return f"https://{self.host}/starknet/version/rpc/v0_10/{key}"
        return f"https://{self.host}/v2/{key}"


@lru_cache(maxsize=1)
def load_manifest(path: Path = DEFAULT_MANIFEST) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def list_networks(*, manifest_path: Path = DEFAULT_MANIFEST) -> List[AlchemyNetwork]:
    data = load_manifest(manifest_path)
    out: List[AlchemyNetwork] = []
    for net_id, row in data.get("networks", {}).items():
        if row.get("enabled") is False:
            continue
        out.append(
            AlchemyNetwork(
                id=net_id,
                name=str(row.get("name", net_id)),
                host=str(row["host"]),
                family=str(row.get("family", "evm")),
                chain_id=row.get("chain_id"),
                url_pattern=str(row.get("url_pattern", "v2")),
                enabled=True,
            )
        )
    return out


def get_network(network_id: str, *, manifest_path: Path = DEFAULT_MANIFEST) -> AlchemyNetwork:
    data = load_manifest(manifest_path)
    row = data.get("networks", {}).get(network_id)
    if not row:
        raise KeyError(f"unknown Alchemy network id: {network_id}")
    return AlchemyNetwork(
        id=network_id,
        name=str(row.get("name", network_id)),
        host=str(row["host"]),
        family=str(row.get("family", "evm")),
        chain_id=row.get("chain_id"),
        url_pattern=str(row.get("url_pattern", "v2")),
        enabled=row.get("enabled", True) is not False,
    )


# Primary YieldSwarm aliases → manifest network ids
DEFAULT_NETWORK_IDS = {
    "solana": "solana-mainnet",
    "solana_devnet": "solana-devnet",
    "ethereum": "ethereum-mainnet",
    "ethereum_sepolia": "ethereum-sepolia",
    "base": "base-mainnet",
    "base_sepolia": "base-sepolia",
    "polygon": "polygon-mainnet",
    "arbitrum": "arbitrum-mainnet",
    "optimism": "op-mainnet",
    "avalanche": "avalanche-mainnet",
    "linea": "linea-mainnet",
    "scroll": "scroll-mainnet",
    "starknet": "starknet-mainnet",
}
