"""OpenClaw Scaler — Iteration 100 mutation loop with Odysseus memory."""

from __future__ import annotations

import json
import os
from pathlib import Path

from iteration_100_sovereign_loops import SovereignController
from odysseus_memory import build_agent_id, get_memory


def main() -> int:
    memory = get_memory()
    shard_id = int(os.getenv("AGENT_SHARD_ID", "0"))
    agent_id = os.getenv("AGENT_ID", build_agent_id(shard_id, 1))

    memory.register_agent_mesh()
    memory.record_cross_agent_learning(
        source_agent_id=agent_id,
        summary=(
            "OpenClaw instances should read/write all durable agent state through "
            "Odysseus ChromaDB memory before dispatching sharded tasks."
        ),
        applies_to=["openclaw", "akash-workers", "all_mutated_agents"],
        confidence=0.99,
        evidence={
            "agent_count_total": memory.config.agent_count_total,
            "agents_per_shard": memory.config.agents_per_shard,
            "shard_count": memory.config.shard_count,
        },
    )

    controller = SovereignController(
        state_path=Path("dashboard/iteration_100_state.json"),
        dashboard_path=Path("dashboard/final-monitoring-dashboard-5m.md"),
    )
    report = controller.run_cycle()

    print(
        json.dumps(
            {
                "loop": "autonomous-agent-mutation",
                "cycle": report["cycle"],
                "mutated_agents": report["mutation_metrics"]["mutated_agents"],
                "avg_fitness_delta": report["mutation_metrics"]["avg_fitness_delta"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
