"""Load treasury manifest mining roots for reward routing."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "config" / "TREASURY_MANIFEST.json"


def load_treasury_manifest() -> dict[str, Any]:
    if MANIFEST_PATH.is_file():
        return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    return {}


def mining_root_wallets() -> dict[str, str]:
    manifest = load_treasury_manifest()
    roots = dict(manifest.get("mining_roots") or {})
    nexus = manifest.get("nexus_treasury") or {}
    if nexus.get("solana"):
        roots["nexus_solana"] = nexus["solana"]
    iotex = manifest.get("iotex_hub") or {}
    if iotex.get("primary"):
        roots.setdefault("iotex", iotex["primary"])
    if iotex.get("btc_bridge"):
        roots.setdefault("btc_via_iopay", iotex["btc_bridge"])
    return roots


def rewards_dry_run() -> bool:
    v = os.environ.get("REWARDS_DRY_RUN", "1").strip().lower()
    return v not in ("0", "false", "no", "off")
