"""Cross-solenoid messaging bus (Nexus Chain internal pub/sub)."""

from __future__ import annotations

import json
import os
import uuid
from collections import deque
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

QUEUE_PATH = Path(os.environ.get("NEXUS_BUS_STATE", Path(__file__).resolve().parents[2] / ".run" / "nexus-bus.jsonl"))
MAX_DEPTH = int(os.environ.get("NEXUS_BUS_MAX_DEPTH", "10000"))


@dataclass
class SolenoidMessage:
    id: str
    source: str
    target: str
    topic: str
    payload: dict[str, Any]
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    ttl_seconds: int = 300

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class MessagingBus:
    """Durable JSONL queue for cross-solenoid commands and events."""

    def __init__(self, path: Path | None = None):
        self.path = path or QUEUE_PATH
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._memory: deque[dict[str, Any]] = deque(maxlen=MAX_DEPTH)

    def publish(self, source: str, target: str, topic: str, payload: dict[str, Any] | None = None,
                ttl_seconds: int = 300) -> SolenoidMessage:
        msg = SolenoidMessage(
            id=str(uuid.uuid4()),
            source=source,
            target=target,
            topic=topic,
            payload=payload or {},
            ttl_seconds=ttl_seconds,
        )
        line = json.dumps(msg.to_dict())
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
        self._memory.append(msg.to_dict())
        return msg

    def consume(self, target: str, *, limit: int = 50) -> list[dict[str, Any]]:
        if not self.path.is_file():
            return []
        out: list[dict[str, Any]] = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("target") in (target, "*"):
                out.append(row)
            if len(out) >= limit:
                break
        return out

    def route_harvest_trigger(self, origin_chain_id: int, amount: int) -> SolenoidMessage:
        return self.publish(
            source="nexus",
            target="helix",
            topic="trigger_remote_harvest",
            payload={"origin_chain_id": origin_chain_id, "amount": amount},
        )

    def route_arena_score(self, agent_id: str, score_bps: int) -> SolenoidMessage:
        return self.publish(
            source="shadow",
            target="nexus",
            topic="arena_score",
            payload={"agent_id": agent_id, "score_bps": score_bps},
        )

    def route_device_status(self, network_id: str, summary: dict[str, Any]) -> SolenoidMessage:
        return self.publish(
            source="iot_hub",
            target="nexus",
            topic="device_status",
            payload={"network_id": network_id, "summary": summary},
        )

    def route_device_heartbeat(self, device_id: str, status: str, metrics: dict[str, Any] | None = None) -> SolenoidMessage:
        return self.publish(
            source="iot_hub",
            target="nexus",
            topic="device_heartbeat",
            payload={"device_id": device_id, "status": status, "metrics": metrics or {}},
        )
