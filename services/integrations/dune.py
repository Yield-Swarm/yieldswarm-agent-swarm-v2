"""Dune Analytics integration for Nexus, Helix, and Shadow Chain."""

from __future__ import annotations

import os
from typing import Any, Dict, List


DASHBOARDS = [
    {"chain": "nexus", "slug": "yieldswarm-nexus-treasury", "env": "DUNE_DASHBOARD_NEXUS"},
    {"chain": "helix", "slug": "yieldswarm-helix-emissions", "env": "DUNE_DASHBOARD_HELIX"},
    {"chain": "shadow", "slug": "yieldswarm-shadow-chain", "env": "DUNE_DASHBOARD_SHADOW"},
]


def dune_status() -> Dict[str, Any]:
    api_key = bool(os.environ.get("DUNE_API_KEY"))
    dashboards = []
    for d in DASHBOARDS:
        url = os.environ.get(d["env"], "")
        dashboards.append({
            "chain": d["chain"],
            "slug": d["slug"],
            "url": url or f"https://dune.com/yieldswarm/{d['slug']}",
            "configured": bool(url),
        })
    return {
        "api_key_configured": api_key,
        "dashboards": dashboards,
        "contracts": [
            "contracts/GreatDeltaEmissionRouter.sol",
        ],
    }
