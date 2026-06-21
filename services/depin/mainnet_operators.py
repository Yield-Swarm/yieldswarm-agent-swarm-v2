"""Mainnet node operator fleet — 12+ operator manifest."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[2]
TARGET_OPERATORS = 12


def _manifest_path() -> Path:
    return Path(os.environ.get("MAINNET_OPERATORS_PATH", REPO_ROOT / "config" / "mainnet" / "operators.json"))


def load_operators() -> List[Dict[str, Any]]:
    path = _manifest_path()
    if not path.exists():
        return _default_operators()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else data.get("operators", [])
    except json.JSONDecodeError:
        return _default_operators()


def _default_operators() -> List[Dict[str, Any]]:
    """Scaffold 12 operator slots — fill via Vault / ops."""
    providers = ["akash", "azure", "zeeve", "local"]
    return [
        {
            "id": f"op-{i + 1:02d}",
            "provider": providers[i % len(providers)],
            "region": os.environ.get(f"OPERATOR_{i + 1}_REGION", "us-west"),
            "status": "provisioned" if os.environ.get(f"OPERATOR_{i + 1}_RPC") else "pending",
            "rpc": os.environ.get(f"OPERATOR_{i + 1}_RPC", ""),
        }
        for i in range(TARGET_OPERATORS)
    ]


def operator_summary() -> Dict[str, Any]:
    ops = load_operators()
    live = sum(1 for o in ops if o.get("status") in ("live", "provisioned") and o.get("rpc"))
    return {
        "target": TARGET_OPERATORS,
        "configured": len(ops),
        "live": live,
        "ready": live >= TARGET_OPERATORS,
        "operators": ops,
    }
