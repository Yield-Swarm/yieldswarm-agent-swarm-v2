"""Chainlink Vault Manager entrypoint for treasury rebalance loop."""

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
                "loop": "dynamic-treasury-rebalancing",
                "cycle": report["cycle"],
                "rebalances": report["treasury_metrics"]["rebalances"],
                "weighted_apy": report["treasury_metrics"]["weighted_apy"],
                "capital_deployed_usd": report["treasury_metrics"]["capital_deployed_usd"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())