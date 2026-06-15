"""Chainlink Vault Manager — treasury rebalance loop with Odysseus memory."""

from __future__ import annotations

import json
import os

import _bootstrap  # noqa: F401

from odysseus_memory import build_agent_id, get_memory


def main() -> int:
    memory = get_memory()
    shard_id = int(os.getenv("AGENT_SHARD_ID", "0"))
    agent_id = os.getenv("AGENT_ID", build_agent_id(shard_id, 2))

    memory.record_performance(
        agent_id=agent_id,
        shard_id=shard_id,
        metric_name="vault_manager_activation",
        metric_value=1.0,
        context={
            "revenue_sources": ["z15_sales", "marketplace", "nft_license_keys"],
            "memory_scope": "odysseus_chromadb_long_term",
        },
    )
    memory.record_cross_agent_learning(
        source_agent_id=agent_id,
        summary=(
            "Revenue routing outcomes should be written to Odysseus performance "
            "history before agents rebalance Akash, Grass, or yield strategies."
        ),
        applies_to=["chainlink-vault", "yield-optimizers", "depin-agents"],
        confidence=0.95,
    )

    print(
        json.dumps(
            {
                "loop": "chainlink-vault-manager",
                "agent_id": agent_id,
                "status": "performance_recorded",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
