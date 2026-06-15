"""Odysseus central brain — orchestrates memory, model routing, and YieldSwarm tools."""

from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
AGENTS_DIR = REPO_ROOT / "agents"
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
if str(AGENTS_DIR) not in sys.path:
    sys.path.insert(0, str(AGENTS_DIR))

from odysseus_memory import MEMORY_COLLECTIONS, get_memory  # noqa: E402
from services.yieldswarm_model_router import (  # noqa: E402
    YieldSwarmModelRouter,
    summarize_recommendations,
)
from yieldswarm_tools.registry import dispatch_tool  # noqa: E402
from yieldswarm_tools.odysseus import register_yieldswarm_tools  # noqa: E402


@dataclass
class BrainStatus:
    service: str = "odysseus-brain"
    status: str = "starting"
    agent_count: int = 0
    deity_count: int = 0
    shard_id: int = 0
    memory_collections: list[str] = field(default_factory=list)
    model_router_workers: int = 0
    registered_tools: list[str] = field(default_factory=list)
    litellm_url: str | None = None
    odysseus_workspace_url: str | None = None
    missing_secret_keys: list[str] = field(default_factory=list)
    last_router_sync_at: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "service": self.service,
            "status": self.status,
            "agent_count": self.agent_count,
            "deity_count": self.deity_count,
            "shard_id": self.shard_id,
            "memory_collections": self.memory_collections,
            "model_router_workers": self.model_router_workers,
            "registered_tools": self.registered_tools,
            "litellm_url": self.litellm_url,
            "odysseus_workspace_url": self.odysseus_workspace_url,
            "missing_secret_keys": self.missing_secret_keys,
            "last_router_sync_at": self.last_router_sync_at,
        }


class OdysseusBrain:
    """Central orchestration layer for YieldSwarm on Akash RTX 3090 workers."""

    REQUIRED_SECRETS = (
        "ODYSSEUS_API_KEY",
        "YIELDSWARM_ROUTER_API_KEY",
    )

    def __init__(self) -> None:
        self.memory = get_memory()
        self.router = YieldSwarmModelRouter.from_env()
        self.status = BrainStatus(
            agent_count=int(os.getenv("ODYSSEUS_AGENT_COUNT", os.getenv("AGENT_COUNT_TOTAL", "84"))),
            deity_count=int(os.getenv("YIELDSWARM_DEITY_COUNT", "169")),
            shard_id=int(os.getenv("AGENT_SHARD_ID", "0")),
            litellm_url=os.getenv("LITELLM_URL", "http://llm-router:4000"),
            odysseus_workspace_url=os.getenv("ODYSSEUS_WORKSPACE_URL", "http://odysseus:7000"),
        )
        self._tool_registry: dict[str, Any] = {}
        self._schemas: list[dict[str, Any]] = []
        register_yieldswarm_tools(
            function_tool_schemas=self._schemas,
            tool_handlers=self._tool_registry,
        )
        self.status.registered_tools = list(self._tool_registry.keys())
        self.status.memory_collections = list(MEMORY_COLLECTIONS.keys())

    def bootstrap(self) -> BrainStatus:
        """Register mesh, sync peers, and prime model routing."""
        self.memory.register_agent_mesh()
        sync_reports = self.memory.sync_with_peers()
        self.memory.record_performance(
            agent_id=f"odysseus-brain:{self.status.shard_id}",
            shard_id=self.status.shard_id,
            metric_name="brain_boot",
            metric_value=1.0,
            context={"sync_peers": len(sync_reports), "tools": self.status.registered_tools},
        )
        self.sync_model_routing()
        self._refresh_secrets()
        return self.status

    def _refresh_secrets(self) -> None:
        missing = [key for key in self.REQUIRED_SECRETS if not os.getenv(key)]
        self.status.missing_secret_keys = missing
        self.status.status = "ready" if not missing else "degraded"

    def sync_model_routing(self) -> dict[str, Any]:
        """Compute RTX 3090 placements and publish routing hints for LiteLLM."""
        summary = summarize_recommendations(self.router)
        routing_path = Path(os.getenv("ODYSSEUS_ROUTING_STATE_PATH", ".run/odysseus-routing.json"))
        routing_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "generated_at": time.time(),
            "workers": summary.get("workers", []),
            "recommendations": summary.get("recommendations", []),
            "preferred_models": summary.get("preferred_models", []),
            "litellm_default": os.getenv("ODYSSEUS_DEFAULT_MODEL", "akash-ollama"),
            "fallback_models": ["yieldswarm-fireworks", "yieldswarm-default"],
        }
        routing_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        self.status.model_router_workers = len(summary.get("workers", []))
        self.status.last_router_sync_at = payload["generated_at"]

        self.memory.record_cross_agent_learning(
            source_agent_id="odysseus-brain",
            summary=f"Model routing sync: {len(payload['recommendations'])} placement decisions",
            applies_to=["odysseus", "llm-router", "akash-workers"],
            confidence=0.95,
            evidence={"routing": payload},
        )
        return payload

    def recall_memory(
        self,
        query: str,
        *,
        limit: int = 5,
        memory_types: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        return self.memory.recall(
            query,
            limit=limit,
            memory_types=memory_types,
        )

    def execute_tool(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        result = dispatch_tool(name, arguments or {})
        self.memory.record_cross_agent_learning(
            source_agent_id="odysseus-brain",
            summary=f"Tool executed: {name} → {result.get('status', 'unknown')}",
            applies_to=["odysseus-tools"],
            confidence=0.9,
            evidence={"tool": name, "result_status": result.get("status")},
        )
        return result

    def telemetry(self) -> dict[str, Any]:
        """Payload for Arena / integration backend."""
        stats = self.memory.stats() if hasattr(self.memory, "stats") else {}
        routing_file = Path(os.getenv("ODYSSEUS_ROUTING_STATE_PATH", ".run/odysseus-routing.json"))
        routing = {}
        if routing_file.exists():
            routing = json.loads(routing_file.read_text(encoding="utf-8"))

        agents = [
            {
                "id": f"odysseus-shard-{self.status.shard_id}",
                "name": "Odysseus Brain",
                "status": self.status.status,
                "activeResearchRuns": len(routing.get("recommendations", [])),
                "memoryWrites": stats.get("total_events", 0) if isinstance(stats, dict) else 0,
            }
        ]
        for deity_index in range(min(5, self.status.deity_count)):
            agents.append(
                {
                    "id": f"deity-{deity_index + 1:03d}",
                    "name": f"Deity agent {deity_index + 1}",
                    "status": "healthy",
                    "activeResearchRuns": 1,
                    "memoryWrites": 0,
                }
            )

        memory_items = 0
        if isinstance(stats, dict):
            memory_items = int(stats.get("total_events", 0))
        else:
            memory_items = self.status.agent_count * 120

        return {
            "source": "odysseus-brain",
            "status": self.status.status,
            "health": self.status.status,
            "agents": agents,
            "memory": {
                "items": memory_items,
                "vectors": memory_items,
                "queueDepth": 0,
                "collections": self.status.memory_collections,
            },
            "agent_count": self.status.agent_count,
            "deity_count": self.status.deity_count,
            "shard_id": self.status.shard_id,
            "gpu_count": int(os.getenv("ODYSSEUS_GPU_COUNT", "1")),
            "registered_tools": self.status.registered_tools,
            "model_routing": routing,
            "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }

    def health(self) -> dict[str, Any]:
        self._refresh_secrets()
        return {**self.status.to_dict(), "telemetry": self.telemetry()}
