"""Track 10,080 autonomous terminal agents across 120 shards."""

from __future__ import annotations

import asyncio
import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


try:
    AGENT_COUNT = min(10080, max(1, int(str(os.environ.get("AGENT_COUNT_TOTAL", "10080")).split(".")[0])))
except ValueError:
    AGENT_COUNT = 10080
AGENTS_PER_SHARD = min(84, max(1, int(os.environ.get("AGENTS_PER_SHARD", "84") or 84)))
SHARD_COUNT = min(120, max(1, int(os.environ.get("CRON_SHARD_COUNT", "120") or 120)))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class AgentTerminal:
    agent_id: str
    shard_id: int
    index: int
    status: str = "idle"
    last_heartbeat: str = field(default_factory=_utc_now)
    alignment_score: float = 0.5


class AgentSpawner:
    """Async-safe registry for 10,080 headless terminal agents."""

    def __init__(self) -> None:
        self._agents: dict[str, AgentTerminal] = {}
        self._lock = asyncio.Lock()
        self._materialized = False

    def _agent_id(self, index: int) -> str:
        return f"chart-agent-{index:05d}"

    async def materialize(self) -> None:
        if self._materialized:
            return
        async with self._lock:
            if self._materialized:
                return
            for i in range(AGENT_COUNT):
                aid = self._agent_id(i)
                self._agents[aid] = AgentTerminal(
                    agent_id=aid,
                    shard_id=i // AGENTS_PER_SHARD,
                    index=i,
                )
            self._materialized = True

    async def heartbeat_shard(self, shard_id: int) -> dict[str, Any]:
        await self.materialize()
        updated = 0
        async with self._lock:
            for agent in self._agents.values():
                if agent.shard_id == shard_id:
                    agent.last_heartbeat = _utc_now()
                    agent.status = "active"
                    updated += 1
        return {"shardId": shard_id, "agentsUpdated": updated, "timestamp": _utc_now()}

    async def apply_human_telemetry(
        self,
        event: dict[str, Any],
        *,
        alignment_delta: float = 0.01,
    ) -> dict[str, Any]:
        await self.materialize()
        layer = int(event.get("layerId", 1))
        shard_id = (layer * 3) % SHARD_COUNT
        trained = 0
        async with self._lock:
            for agent in self._agents.values():
                if agent.shard_id == shard_id:
                    agent.alignment_score = min(1.0, agent.alignment_score + alignment_delta)
                    agent.status = "training"
                    trained += 1
                    if trained >= AGENTS_PER_SHARD:
                        break
        return {
            "schemaVersion": "agent-spawner/v1",
            "correlationId": event.get("correlationId", str(uuid.uuid4())),
            "shardId": shard_id,
            "agentsTrained": trained,
            "eventType": event.get("eventType"),
        }

    def stats(self) -> dict[str, Any]:
        active = sum(1 for a in self._agents.values() if a.status == "active")
        training = sum(1 for a in self._agents.values() if a.status == "training")
        return {
            "totalAgents": len(self._agents) or AGENT_COUNT,
            "activeAgents": active,
            "trainingAgents": training,
            "shardCount": SHARD_COUNT,
            "agentsPerShard": AGENTS_PER_SHARD,
        }
