"""Helix Chain duadilateral route tick — Base, ETH, TON, TAO, AVAX."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[2]
ROUTES_FILE = REPO_ROOT / "config" / "helix" / "chain-routes.json"


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


def load_routes_config() -> Dict[str, Any]:
    return json.loads(ROUTES_FILE.read_text())


def tick_duadilateral_routes(*, dry_run: bool | None = None) -> Dict[str, Any]:
    """Emit a sovereign-loop receipt for all Helix duadilateral lanes."""
    if dry_run is None:
        dry_run = os.getenv("CROSS_CHAIN_DRY_RUN", "1").lower() in ("1", "true", "yes")

    cfg = load_routes_config()
    now = int(time.time())
    routes: List[Dict[str, Any]] = []

    for route in cfg.get("duadilaterals", []):
        target = cfg["targets"][route["target"]]
        routes.append(
            {
                "id": route["id"],
                "duadilateral": f"{route['source']}↔{route['target']}",
                "source": route["source"],
                "target": route["target"],
                "lane": route["lane"],
                "chain_id": target.get("chain_id"),
                "native_symbol": target.get("native_symbol"),
                "status": "dry_run" if dry_run else "armed",
                "bidirectional": True,
            }
        )

    summary = {
        "run_at": now,
        "dry_run": dry_run,
        "policy": cfg.get("policy"),
        "targets": list(cfg.get("targets", {}).keys()),
        "route_count": len(routes),
        "routes": routes,
    }

    out = _run_dir() / "helix-duadilateral-last-run.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2))
    return summary
