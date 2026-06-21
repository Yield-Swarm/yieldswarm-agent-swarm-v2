"""Registry of all 20 YieldSwarm Single Pane prompts with live status."""

from __future__ import annotations

import importlib
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List

REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class PromptDef:
    id: int
    slug: str
    title: str
    category: str
    artifact_paths: tuple[str, ...]


PROMPTS: tuple[PromptDef, ...] = (
    PromptDef(1, "node5", "Node 5 Stellar + Cosmos SDK", "core", ("nodes/node5/", "agents/node5_orchestrator.py")),
    PromptDef(2, "mining", "Unified mining manager (TAO, XMR, ETC, PoW)", "core", ("mining/manager.py", "backend/src/routes/mining.js")),
    PromptDef(3, "iot", "IoT device registry", "core", ("services/iot/device_registry.py", "backend/src/routes/iot.js")),
    PromptDef(4, "command_center", "TV command-center dashboard", "core", ("dashboard/command-center.html", "backend/src/routes/tv.js")),
    PromptDef(5, "tesla_dojo", "Tesla Fleet API + Dojo logic", "infra", ("src/infrastructure/entropy-core.js", "docs/TESLA_FLEET_INTEGRATION.md")),
    PromptDef(6, "yslr", "YSLR encrypted task queue", "infra", ("services/yslr/queue.py",)),
    PromptDef(7, "neural_mesh", "Neural Mesh 14 parallel elevators", "infra", ("services/neural_mesh/elevators.py", "backend/src/routes/solenoid.js")),
    PromptDef(8, "utc", "Universal Time Coordinate + atomic scheduler", "infra", ("services/utc/scheduler.py", "services/cloud_scheduler/scheduler.py")),
    PromptDef(9, "astro", "Astrological Schedule Engine (Aquarius)", "infra", ("services/astro_schedule/engine.py",)),
    PromptDef(10, "chain_sdks", "Multi-chain SDK integrations", "blockchain", ("services/cross_chain/", "services/integrations/")),
    PromptDef(11, "helix_sharding", "Helix Chain A+1 sharding", "blockchain", ("services/helix/sharding.py", "backend/src/adapters/helix.js")),
    PromptDef(12, "agent_oauth", "Autonomous agent deployment OAuth2", "blockchain", ("services/agent_deploy/oauth.py", "vault/setup/04-enable-auth.sh")),
    PromptDef(13, "mainnet_ops", "Mainnet 12+ node operators", "blockchain", ("services/depin/mainnet_operators.py",)),
    PromptDef(14, "deploy", "Dashboard Vercel/Render + Neon", "frontend", ("vercel.json", "render.yaml", "services/neon_store.py")),
    PromptDef(15, "visualizer", "Neural mesh frequency visualizer", "frontend", ("dashboard/neural-mesh-viz.html",)),
    PromptDef(16, "multi_screen", "Fire TV / Apple TV multi-screen sync", "frontend", ("services/iot/sync_hub.py",)),
    PromptDef(17, "profit_share", "Jack the Dab Lad 3% profit share", "business", ("services/business/profit_share.py",)),
    PromptDef(18, "magic_links", "Magic link auth for team", "business", ("services/business/magic_links.py",)),
    PromptDef(19, "dune", "Dune Analytics dashboards", "business", ("services/integrations/dune.py",)),
    PromptDef(20, "quickbooks", "QuickBooks payroll integration", "business", ("services/integrations/quickbooks.py",)),
)


def _artifact_exists(rel: str) -> bool:
    return (REPO_ROOT / rel).exists()


def _probe_module(module: str) -> bool:
    try:
        importlib.import_module(module)
        return True
    except Exception:
        return False


class PromptRegistry:
    """Evaluate prompt completion from artifact presence and optional probes."""

    PROBES: Dict[str, str] = {
        "node5": "nodes.node5",
        "iot": "services.iot.device_registry",
        "yslr": "services.yslr.queue",
        "utc": "services.utc.scheduler",
        "astro": "services.astro_schedule.engine",
        "profit_share": "services.business.profit_share",
        "magic_links": "services.business.magic_links",
    }

    def status_for(self, prompt: PromptDef) -> Dict[str, Any]:
        artifacts = list(prompt.artifact_paths)
        present = sum(1 for a in artifacts if _artifact_exists(a))
        ratio = present / len(artifacts) if artifacts else 0.0
        probe_ok = _probe_module(self.PROBES[prompt.slug]) if prompt.slug in self.PROBES else None

        if ratio >= 1.0 and (probe_ok is None or probe_ok):
            state = "ready"
        elif ratio >= 0.5:
            state = "partial"
        else:
            state = "missing"

        return {
            "id": prompt.id,
            "slug": prompt.slug,
            "title": prompt.title,
            "category": prompt.category,
            "status": state,
            "artifacts_present": present,
            "artifacts_total": len(artifacts),
            "artifacts": artifacts,
        }

    def all_statuses(self) -> List[Dict[str, Any]]:
        return [self.status_for(p) for p in PROMPTS]

    def summary(self) -> Dict[str, Any]:
        statuses = self.all_statuses()
        ready = sum(1 for s in statuses if s["status"] == "ready")
        partial = sum(1 for s in statuses if s["status"] == "partial")
        return {
            "total": len(statuses),
            "ready": ready,
            "partial": partial,
            "missing": len(statuses) - ready - partial,
            "prompts": statuses,
        }


def get_prompt_status() -> Dict[str, Any]:
    reg = PromptRegistry()
    return reg.summary()
