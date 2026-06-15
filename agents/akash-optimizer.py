# Akash Optimizer Agent
# Connects to current allocations (GPU miners, OpenClaw, Eliza, Gensyn)
# Optimizes leases, model placement, and YieldSwarm Cookbook inference routes.

from __future__ import annotations

import json
import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from services.yieldswarm_model_router import (  # noqa: E402
    YieldSwarmModelRouter,
    summarize_recommendations,
)


def optimize_akash_gpu_fleet() -> dict:
    """Recommend active model placements for the Akash RTX 3090 fleet."""

    router = YieldSwarmModelRouter.from_env()
    return summarize_recommendations(router)


if __name__ == "__main__":
    print("Akash Optimizer Agent active - optimizing RTX 3090 model routes")
    print(json.dumps(optimize_akash_gpu_fleet(), indent=2, sort_keys=True))
