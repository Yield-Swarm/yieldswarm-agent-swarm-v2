"""Helical message bus — rotates epochs across 4 swarms every 420s heartbeat."""

from __future__ import annotations

import json
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

SWARM_ORDER = ["physical-core", "mining-pools", "marketplace", "mmorpg"]
HEARTBEAT_SECONDS = 420


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class HelicalBus:
    """Route envelopes between swarms with epoch/phase rotation."""

    def __init__(self, state_path: Path | None = None) -> None:
        self.state_path = state_path or Path("dashboard/helical-state.json")
        self._handlers: dict[str, Callable[[dict[str, Any]], dict[str, Any]]] = {}

    def register(self, swarm_id: str, handler: Callable[[dict[str, Any]], dict[str, Any]]) -> None:
        self._handlers[swarm_id] = handler

    def load_state(self) -> dict[str, Any]:
        if self.state_path.exists():
            return json.loads(self.state_path.read_text(encoding="utf-8"))
        return self._genesis_state()

    def save_state(self, state: dict[str, Any]) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        state["updatedAt"] = _utc_now()
        self.state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")

    def _genesis_state(self) -> dict[str, Any]:
        return {
            "schemaVersion": "helical-state/v1",
            "activated": False,
            "epoch": 0,
            "phase": 0,
            "heartbeatSeconds": HEARTBEAT_SECONDS,
            "updatedAt": _utc_now(),
            "site": {
                "siteId": "carrizozo-nm-10ac",
                "name": "YieldSwarm Sovereign Data Ranch",
                "latitude": 33.6417,
                "longitude": -105.8772,
                "acreage": 10,
            },
            "swarms": {sid: {"status": "genesis", "lastHeartbeatAt": None, "metrics": {}, "blockers": []} for sid in SWARM_ORDER},
            "receipts": [],
        }

    def wrap_envelope(
        self,
        swarm_id: str,
        payload: dict[str, Any],
        *,
        epoch: int,
        phase: int,
        correlation_id: str | None = None,
    ) -> dict[str, Any]:
        return {
            "schemaVersion": "helical-envelope/v1",
            "swarmId": swarm_id,
            "epoch": epoch,
            "phase": phase,
            "messageId": str(uuid.uuid4()),
            "correlationId": correlation_id or str(uuid.uuid4()),
            "emittedAt": _utc_now(),
            "siteId": "carrizozo-nm-10ac",
            "latencyMs": None,
            "treasurySplit": "50,30,15,5",
            "payload": payload,
        }

    def rotate_epoch(self, state: dict[str, Any]) -> dict[str, Any]:
        state["epoch"] = int(state.get("epoch", 0)) + 1
        state["phase"] = int(state["epoch"]) % 4
        return state

    def run_heartbeat(self) -> dict[str, Any]:
        state = self.load_state()
        phase = int(state.get("phase", 0))
        swarm_id = SWARM_ORDER[phase]
        handler = self._handlers.get(swarm_id)
        payload: dict[str, Any] = {}
        if handler:
            payload = handler({})
            state["swarms"][swarm_id]["status"] = "active"
            state["swarms"][swarm_id]["lastHeartbeatAt"] = _utc_now()
            state["swarms"][swarm_id]["metrics"] = {
                "keys": list(payload.keys())[:8],
            }
        envelope = self.wrap_envelope(swarm_id, payload, epoch=state["epoch"], phase=phase)
        state["receipts"] = (state.get("receipts") or [])[-99:]
        state["receipts"].append(
            {
                "messageId": envelope["messageId"],
                "swarmId": swarm_id,
                "epoch": envelope["epoch"],
                "emittedAt": envelope["emittedAt"],
                "summary": f"phase-{phase} heartbeat",
            }
        )
        state = self.rotate_epoch(state)
        if not state.get("activated"):
            state["activated"] = True
        self.save_state(state)
        return envelope

    def sleep_until_next(self) -> None:
        time.sleep(HEARTBEAT_SECONDS)
