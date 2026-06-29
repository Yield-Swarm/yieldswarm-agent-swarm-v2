"""35-layer mesh network — headless backend for Godot 4 / Bevy clients."""

from __future__ import annotations

import asyncio
import json
import os
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


LAYER_COUNT = min(35, max(1, int(os.environ.get("MESH_LAYER_COUNT", "35") or 35)))
_raw_agents = os.environ.get("AGENT_COUNT_TOTAL", "10080")
try:
    AGENT_COUNT = min(10080, max(1, int(str(_raw_agents).split(".")[0])))
except ValueError:
    AGENT_COUNT = 10080
AGENTS_PER_SHARD = min(84, max(1, int(os.environ.get("AGENTS_PER_SHARD", "84") or 84)))
SHARD_COUNT = min(120, max(1, int(os.environ.get("CRON_SHARD_COUNT", "120") or 120)))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class MeshLayer:
    layer_id: int
    name: str
    agent_slots: int
    state: dict[str, Any] = field(default_factory=dict)


class LayerMesh:
    """Thread-safe async 35-layer mesh with deterministic agent slot mapping."""

    def __init__(self) -> None:
        self.layers: list[MeshLayer] = []
        self._lock = asyncio.Lock()
        slots_per_layer = max(1, AGENT_COUNT // max(1, LAYER_COUNT))
        for i in range(LAYER_COUNT):
            self.layers.append(
                MeshLayer(
                    layer_id=i + 1,
                    name=f"layer-{i + 1:02d}",
                    agent_slots=slots_per_layer,
                )
            )

    def agent_to_layer(self, agent_index: int) -> int:
        return (agent_index % LAYER_COUNT) + 1

    def shard_for_agent(self, agent_index: int) -> int:
        return agent_index // AGENTS_PER_SHARD

    async def inject_telemetry(self, event: dict[str, Any]) -> dict[str, Any]:
        async with self._lock:
            agent_index = int(event.get("agentIndex", 0)) % AGENT_COUNT
            layer_id = self.agent_to_layer(agent_index)
            layer = self.layers[layer_id - 1]
            layer.state = {
                "lastEvent": event.get("eventType", "telemetry"),
                "source": event.get("source", "unknown"),
                "xpDelta": event.get("xpDelta", 0),
                "updatedAt": _utc_now(),
            }
            propagated = []
            for offset in range(1, 4):
                downstream = min(LAYER_COUNT, layer_id + offset)
                self.layers[downstream - 1].state["upstreamSignal"] = event.get("eventType")
                propagated.append(downstream)
            return {
                "agentIndex": agent_index,
                "shardId": self.shard_for_agent(agent_index),
                "layerId": layer_id,
                "propagatedLayers": propagated,
                "meshEpoch": int(time.time()),
            }

    def snapshot(self) -> dict[str, Any]:
        active = sum(1 for l in self.layers if l.state)
        return {
            "schemaVersion": "mesh-engine/v1",
            "capturedAt": _utc_now(),
            "layerCount": LAYER_COUNT,
            "agentCount": AGENT_COUNT,
            "shardCount": SHARD_COUNT,
            "activeLayers": active,
            "layers": [
                {"id": l.layer_id, "name": l.name, "slots": l.agent_slots, "hasState": bool(l.state)}
                for l in self.layers
            ],
        }
