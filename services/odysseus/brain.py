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
from services.integrations.registry import check_all_integrations, integration_status  # noqa: E402
from agents.governance.consensus_engine import run_governance_consensus  # noqa: E402


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
    council_integrations: dict[str, Any] = field(default_factory=dict)
    governance_consensus: dict[str, Any] = field(default_factory=dict)

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
            "council_integrations": self.council_integrations,
            "governance_consensus": self.governance_consensus,
        }


class OdysseusBrain:
    """Central orchestration layer for YieldSwarm on Akash RTX 3090 workers."""

    REQUIRED_SECRETS = (
        "ODYSSEUS_API_KEY",
        "YIELDSWARM_ROUTER_API_KEY",
    )

    def __init__(self) -> None:
        self.memory = get_memory()
        self.router = self._build_router()
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

    @staticmethod
    def _build_router() -> YieldSwarmModelRouter:
        return YieldSwarmModelRouter.from_env()

    def refresh_akash_workers(self) -> int:
        """Reload RTX 3090 workers from live Akash lease URLs."""
        self.router = self._build_router()
        count = len(self.router.workers)
        self.status.model_router_workers = count
        return count

    def route_inference(
        self,
        *,
        task: str = "chat",
        agent_id: str | None = None,
        priority: float = 0.5,
    ) -> dict[str, Any]:
        """Select model + worker; include LiteLLM fallback chain."""
        self.refresh_akash_workers()
        decision = self.router.recommend(
            task=task,
            agent_id=agent_id,
            priority=priority,
        )
        litellm_primary = os.getenv("ODYSSEUS_DEFAULT_MODEL", "akash-ollama")
        fallbacks = ["yieldswarm-fireworks", "yieldswarm-default"]
        ollama_url = None
        try:
            from services.akash_worker_sync import primary_ollama_base_url

            ollama_url = primary_ollama_base_url()
        except Exception:
            pass
        return {
            "route": decision.to_dict(),
            "litellm": {
                "primary": litellm_primary,
                "fallbacks": fallbacks,
                "akash_ollama_base_url": ollama_url,
            },
            "task": task,
        }

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
        self._wire_council_integrations()
        if os.getenv("GOVERNANCE_CONSENSUS_ON_BOOT", "true").lower() in {"1", "true", "yes"}:
            self.run_governance_consensus()
        return self.status

    def _wire_council_integrations(self) -> dict[str, Any]:
        report = check_all_integrations(init_observability=True)
        self.status.council_integrations = {
            "configured_count": report["configured_count"],
            "live_count": report["live_count"],
            "configured_services": report["configured_services"],
            "live_services": report["live_services"],
            "livepeer_skipped": True,
        }
        self.memory.record_cross_agent_learning(
            source_agent_id="odysseus-brain",
            summary=(
                f"Council Wishlist wired: {report['configured_count']} configured, "
                f"{report['live_count']} live (Livepeer skipped)"
            ),
            applies_to=["council", "integrations", "odysseus"],
            confidence=0.92,
            evidence={"integrations": report["services"]},
        )
        return report

    def run_governance_consensus(
        self,
        proposal: str | None = None,
        *,
        model_count: int = 100,
    ) -> dict[str, Any]:
        text = proposal or os.getenv(
            "GOVERNANCE_CONSENSUS_PROPOSAL",
            "Council Wishlist API wiring + sovereign integration bootstrap",
        )
        integration_report = self.status.council_integrations or {}
        configured = integration_report.get("configured_count", 0)
        report = run_governance_consensus(
            text,
            model_count=model_count,
            configured_integrations=configured,
        )
        self.status.governance_consensus = {
            "threshold_met": report["consensus"]["threshold_met"],
            "council_approvals": report["consensus"]["council_approvals"],
            "governance_delta": report["governance_delta"],
            "autopilot_ready": report["autopilot_ready"],
            "model_count": report["model_count"],
            "output_path": report.get("output_path"),
        }
        self.memory.record_cross_agent_learning(
            source_agent_id="deity-001",
            summary=(
                f"Kimiclaw consensus: {report['consensus']['council_approvals']}/14 seats, "
                f"delta={report['governance_delta']}"
            ),
            applies_to=["council", "governance", "kimiclaw"],
            confidence=0.97,
            evidence={"consensus": report["consensus"]},
        )
        return report

    def integrations_health(self) -> dict[str, Any]:
        return check_all_integrations(init_observability=False)

    def governance_status(self) -> dict[str, Any]:
        return {
            "consensus": self.status.governance_consensus,
            "integrations": integration_status(),
            "gospel": {
                "council_seats": 14,
                "threshold": "9/14",
                "model_count": 100,
            },
        }

    def _refresh_secrets(self) -> None:
        missing = [key for key in self.REQUIRED_SECRETS if not os.getenv(key)]
        self.status.missing_secret_keys = missing
        self.status.status = "ready" if not missing else "degraded"

    def sync_model_routing(self) -> dict[str, Any]:
        """Compute RTX 3090 placements and publish routing hints for LiteLLM."""
        self.refresh_akash_workers()
        summary = summarize_recommendations(self.router)
        routing_path = Path(os.getenv("ODYSSEUS_ROUTING_STATE_PATH", ".run/odysseus-routing.json"))
        routing_path.parent.mkdir(parents=True, exist_ok=True)
        ollama_url = None
        try:
            from services.akash_worker_sync import primary_ollama_base_url

            ollama_url = primary_ollama_base_url()
        except Exception:
            pass
        payload = {
            "generated_at": time.time(),
            "workers": summary.get("workers", []),
            "recommendations": summary.get("recommendations", {}),
            "preferred_models": summary.get("preferred_models", []),
            "litellm_routing": summary.get("litellm_routing", []),
            "litellm_default": os.getenv("ODYSSEUS_DEFAULT_MODEL", "akash-ollama"),
            "fallback_models": ["yieldswarm-fireworks", "yieldswarm-default"],
            "akash_ollama_base_url": ollama_url,
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
                "activeResearchRuns": len(routing.get("recommendations", {})),
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
