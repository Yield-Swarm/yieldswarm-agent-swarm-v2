"""Akash Optimizer — lease self-healing, model routing, and Odysseus memory."""

from __future__ import annotations

import json
import os
import pathlib
import sys
from pathlib import Path

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from iteration_100_sovereign_loops import SovereignController
from odysseus_memory import build_agent_id, get_memory
from services.yieldswarm_model_router import (  # noqa: E402
    YieldSwarmModelRouter,
    summarize_recommendations,
)


def optimize_akash_gpu_fleet() -> dict:
    """Recommend active model placements for the Akash RTX 3090 fleet."""
    router = YieldSwarmModelRouter.from_env()
    return summarize_recommendations(router)


def main() -> int:
    memory = get_memory()
    shard_id = int(os.getenv("AGENT_SHARD_ID", "0"))
    agent_id = os.getenv("AGENT_ID", build_agent_id(shard_id, 0))

    memory.register_agent_mesh()
    memory.record_performance(
        agent_id=agent_id,
        shard_id=shard_id,
        metric_name="akash_optimizer_boot",
        metric_value=1.0,
        context={"dseq_monitoring": True, "worker_node": memory.config.node_id},
    )
    sync_reports = memory.sync_with_peers()

    controller = SovereignController(
        state_path=Path("dashboard/iteration_100_state.json"),
        dashboard_path=Path("dashboard/final-monitoring-dashboard-5m.md"),
    )
    report = controller.run_cycle()
    routing = optimize_akash_gpu_fleet()

    print(
        json.dumps(
            {
                "loop": "self-healing-akash-leases",
                "cycle": report["cycle"],
                "healed_or_renewed": report["lease_metrics"]["healed_or_renewed"],
                "health_ratio": report["lease_metrics"]["health_ratio"],
                "avg_sla": report["lease_metrics"]["avg_sla"],
                "model_routing": routing,
                "odysseus_sync_reports": sync_reports,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
