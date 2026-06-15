"""OpenClaw Scaler entrypoint for Iteration 100 mutation loop."""

from __future__ import annotations

import json
from pathlib import Path

from iteration_100_sovereign_loops import SovereignController


def main() -> int:
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