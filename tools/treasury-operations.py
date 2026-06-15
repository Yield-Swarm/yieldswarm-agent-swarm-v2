#!/usr/bin/env python3
"""
Odysseus Treasury Operations for YieldSwarm.
Routes revenue splits: 20% ops / 80% yield optimization via Chainlink vault.
"""

import json
import os
import urllib.request
from datetime import datetime, timezone

API_URL = os.environ.get("API_URL", "http://localhost:3000")
TREASURY_ETH = os.environ.get(
    "TREASURY_ETH_WALLET", "0x9505578Bd5b32468E3cEa632664F7b8d2e46128c"
)
OPS_SPLIT = float(os.environ.get("TREASURY_OPS_SPLIT", "0.20"))
YIELD_SPLIT = float(os.environ.get("TREASURY_YIELD_SPLIT", "0.80"))


def fetch_payment_stats() -> dict:
    req = urllib.request.Request(f"{API_URL}/api/v1/payments/stats")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def fetch_agent_stats() -> dict:
    req = urllib.request.Request(f"{API_URL}/api/v1/odysseus/agents/stats")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def compute_treasury_allocation(revenue_cents: int) -> dict:
    ops_cents = int(revenue_cents * OPS_SPLIT)
    yield_cents = int(revenue_cents * YIELD_SPLIT)
    return {
        "treasury_wallet": TREASURY_ETH,
        "total_revenue_cents": revenue_cents,
        "ops_allocation_cents": ops_cents,
        "yield_allocation_cents": yield_cents,
        "ops_split": OPS_SPLIT,
        "yield_split": YIELD_SPLIT,
        "yield_targets": [
            {"name": "akash_gpu", "weight": 0.4},
            {"name": "grass_depin", "weight": 0.2},
            {"name": "apn_lp", "weight": 0.2},
            {"name": "bittensor", "weight": 0.2},
        ],
    }


def run_treasury_report() -> dict:
    payments = fetch_payment_stats()
    agents = fetch_agent_stats()
    allocation = compute_treasury_allocation(payments.get("totalRevenueCents", 0))

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "payments": payments,
        "agents": agents,
        "allocation": allocation,
        "status": "ready",
    }


if __name__ == "__main__":
    print(json.dumps(run_treasury_report(), indent=2))
