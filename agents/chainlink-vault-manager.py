"""Chainlink Vault Manager — treasury rebalance loop with Odysseus memory."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import _bootstrap  # noqa: F401

from odysseus_memory import build_agent_id, get_memory

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def _run_treasury_rebalance() -> dict:
    """Execute Great Delta policy rebalance via sovereign runtime treasury overlay."""
    from services.live_treasury import (
        compute_policy_rebalance,
        fetch_treasury_overlay,
        write_treasury_overlay,
    )

    overlay = fetch_treasury_overlay()
    actions, moved = compute_policy_rebalance(overlay)
    write_treasury_overlay(overlay)
    return {
        "source": overlay.source,
        "live": overlay.live,
        "total_usd": overlay.total_usd,
        "policy_moves_usd": moved,
        "actions": actions,
        "split_policy": "50/30/15/5",
    }


def main() -> int:
    memory = get_memory()
    shard_id = int(os.getenv("AGENT_SHARD_ID", "0"))
    agent_id = os.getenv("AGENT_ID", build_agent_id(shard_id, 2))

    rebalance = _run_treasury_rebalance()

    memory.record_performance(
        agent_id=agent_id,
        shard_id=shard_id,
        metric_name="vault_manager_rebalance",
        metric_value=rebalance.get("policy_moves_usd", 0.0),
        context={
            "revenue_sources": ["z15_sales", "marketplace", "nft_license_keys"],
            "treasury_source": rebalance.get("source"),
            "treasury_live": rebalance.get("live"),
            "split_policy": rebalance.get("split_policy"),
            "actions": len(rebalance.get("actions", [])),
            "memory_scope": "odysseus_chromadb_long_term",
        },
    )
    memory.record_cross_agent_learning(
        source_agent_id=agent_id,
        summary=(
            "Treasury rebalance outcomes (50/30/15/5) should be recorded before "
            "agents rebalance Akash, Grass, or yield strategies."
        ),
        applies_to=["chainlink-vault", "yield-optimizers", "depin-agents"],
        confidence=0.95,
    )

    print(
        json.dumps(
            {
                "loop": "chainlink-vault-manager",
                "agent_id": agent_id,
                "status": "rebalance_computed",
                "rebalance": rebalance,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
