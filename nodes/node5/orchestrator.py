"""Node 5 orchestrator — callable from sovereign loop and cross-chain executor."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from nodes.node5.config import Node5Config, load_node5_config
from nodes.node5.cosmos.client import CosmosClient
from nodes.node5.stellar.client import StellarClient


class Node5Orchestrator:
    """Coordinates Stellar + Cosmos SDK operations for PyHackathon Node 5."""

    def __init__(self, config: Optional[Node5Config] = None):
        self.config = config or load_node5_config()
        self.stellar = StellarClient(self.config.stellar, dry_run=self.config.dry_run)
        self.cosmos = CosmosClient(self.config.cosmos, dry_run=self.config.dry_run)

    def run_cycle(self, *, actions: Optional[List[str]] = None) -> Dict[str, Any]:
        if not self.config.enabled:
            return {"ok": True, "skipped": True, "reason": "NODE5_ENABLED=0"}

        acts = actions or self.config.actions
        report: Dict[str, Any] = {
            "ok": True,
            "node": "node5",
            "module": "pyhackathon-stellar-cosmos",
            "timestamp": int(time.time()),
            "dry_run": self.config.dry_run,
            "config": self.config.redacted(),
            "results": {},
        }

        for action in acts:
            handler = getattr(self, f"_action_{action}", None)
            if not callable(handler):
                report["results"][action] = {"ok": False, "error": f"unknown action: {action}"}
                continue
            try:
                report["results"][action] = handler()
            except Exception as exc:  # noqa: BLE001
                report["results"][action] = {"ok": False, "error": str(exc)}
                report["ok"] = False

        return report

    def _action_status(self) -> Dict[str, Any]:
        return {
            "ok": True,
            "stellar": self.stellar.status(),
            "cosmos": self.cosmos.status(),
        }

    def _action_balance(self) -> Dict[str, Any]:
        return {
            "ok": True,
            "stellar": self.stellar.get_balance(),
            "cosmos": self.cosmos.get_balance(),
        }

    def _action_route_yield(self) -> Dict[str, Any]:
        """Route nominal yield to configured Stellar treasury (dry-run safe)."""
        amount = "1.0"
        dest = self.config.stellar.destination
        payment = self.stellar.submit_payment(amount=amount, destination=dest, memo="node5-yield")
        return {"ok": payment.ok, "stellar_payment": payment.to_dict()}

    def persist_report(self, report: Dict[str, Any], run_dir: Path) -> Path:
        run_dir.mkdir(parents=True, exist_ok=True)
        path = run_dir / "node5-last-run.json"
        path.write_text(json.dumps(report, indent=2))
        return path


def run_cycle(
    *,
    actions: Optional[List[str]] = None,
    run_dir: Optional[Path] = None,
    config: Optional[Node5Config] = None,
) -> Dict[str, Any]:
    """Production entrypoint for swarm_runner and agents."""
    orch = Node5Orchestrator(config=config)
    report = orch.run_cycle(actions=actions)
    if run_dir is not None:
        orch.persist_report(report, run_dir)
    return report
