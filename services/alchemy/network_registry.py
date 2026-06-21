"""Alchemy network registry loader."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = ROOT / "config" / "alchemy" / "networks.json"


@dataclass(frozen=True)
class AlchemyNetwork:
    id: str
    platform: str
    name: str
    slug: str
    url_template: str
    rpc_family: str
    is_testnet: bool

    def rpc_url(self, api_key: str) -> str:
        return self.url_template.replace("API_KEY", api_key)


def load_networks(path: Path = DEFAULT_REGISTRY) -> List[AlchemyNetwork]:
    data = json.loads(path.read_text(encoding="utf-8"))
    out: List[AlchemyNetwork] = []
    for row in data.get("networks", []):
        out.append(
            AlchemyNetwork(
                id=str(row["id"]),
                platform=str(row["platform"]),
                name=str(row["name"]),
                slug=str(row["slug"]),
                url_template=str(row["urlTemplate"]),
                rpc_family=str(row["rpcFamily"]),
                is_testnet=bool(row["isTestnet"]),
            )
        )
    return out


def partition_networks(
    networks: List[AlchemyNetwork],
) -> tuple[List[AlchemyNetwork], List[AlchemyNetwork]]:
    mainnets = [n for n in networks if not n.is_testnet]
    testnets = [n for n in networks if n.is_testnet]
    return mainnets, testnets


def filter_networks(
    networks: List[AlchemyNetwork],
    *,
    family: Optional[str] = None,
    slug_prefix: Optional[str] = None,
    limit: Optional[int] = None,
) -> List[AlchemyNetwork]:
    out = networks
    if family:
        out = [n for n in out if n.rpc_family == family]
    if slug_prefix:
        out = [n for n in out if n.slug.startswith(slug_prefix)]
    if limit is not None:
        out = out[:limit]
    return out
