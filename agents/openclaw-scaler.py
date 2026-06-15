"""OpenClaw Scaler — Iteration 100 mutation loop with Odysseus memory."""

from __future__ import annotations

import json
import os

import _bootstrap  # noqa: F401

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

    print(
        json.dumps(
            {
                "loop": "openclaw-scaler",
                "agent_id": agent_id,
                "shard_id": shard_id,
                "status": "registered",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
