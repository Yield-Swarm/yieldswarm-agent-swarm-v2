"""Akash Optimizer — lease self-healing, ROI optimization, and Odysseus memory."""

from __future__ import annotations

import json
import os
from pathlib import Path

from iteration_100_sovereign_loops import SovereignController
from odysseus_memory import build_agent_id, get_memory


def main() -> int:
    memory = get_memory()
    shard_id = int(os.getenv("AGENT_SHARD_ID", "0"))
    agent_id = os.getenv("AGENT_ID", build_agent_id(shard_id, 0))

    memory.register_agent_mesh()
    memory.record_mutation(
        agent_id=agent_id,
        shard_id=shard_id,
        mutation={
            "type": "akash_lease_optimization",
            "target": "openclaw_gpu_cpu_leases",
            "strategy": "top_up_high_roi_leases_and_migrate_unhealthy_providers",
        },
        outcome={"status": "planned", "sync_scope": "all_odysseus_peers"},
        tags=["akash", "openclaw", "multi-cloud", "odysseus-memory"],
    )
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

    print(
        json.dumps(
            {
                "loop": "self-healing-akash-leases",
                "cycle": report["cycle"],
                "healed_or_renewed": report["lease_metrics"]["healed_or_renewed"],
                "health_ratio": report["lease_metrics"]["health_ratio"],
                "avg_sla": report["lease_metrics"]["avg_sla"],
                "odysseus_sync_reports": sync_reports,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
