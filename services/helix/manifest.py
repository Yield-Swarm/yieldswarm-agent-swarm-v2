"""Helix treasury manifest loader — sync on-chain mining roots with Vault."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "config" / "TREASURY_MANIFEST.json"

# Destination indices — must match onchain/programs/helix/src/mining_roots.rs
DESTINATION_ORDER = [
    "nexus_treasury",
    "iotex",
    "btc_via_iopay",
    "base_etc",
    "zec",
    "prl",
    "tao",
    "base_hype",
    "base_cbeth",
    "base_btc",
]


def load_manifest() -> dict[str, Any]:
    if not MANIFEST_PATH.is_file():
        return {}
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def mining_root_addresses() -> dict[str, str]:
    manifest = load_manifest()
    roots = dict(manifest.get("mining_roots", {}))
    nexus = manifest.get("nexus_treasury", {}).get("solana")
    if nexus:
        roots["nexus_treasury"] = nexus
    return roots


def destination_index(name: str) -> int | None:
    try:
        return DESTINATION_ORDER.index(name)
    except ValueError:
        return None


def routing_summary() -> dict[str, Any]:
    roots = mining_root_addresses()
    return {
        "manifest": str(MANIFEST_PATH),
        "destinations": [
            {"index": i, "key": key, "address": roots.get(key, "")}
            for i, key in enumerate(DESTINATION_ORDER)
        ],
        "iotex_hub": load_manifest().get("iotex_hub", {}),
    }
