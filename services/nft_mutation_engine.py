#!/usr/bin/env python3
"""
Batch NFT mutation engine — listens for WeeklyMutationTriggered or runs on schedule.

Fetches Arena performance data, computes tiers, and calls AgentNFT.mutate() in batches.
Dry-run by default; set MUTATION_ENGINE_DRY_RUN=0 + SOVEREIGN_PRIVATE_KEY for live txs.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class MutationPlan:
    token_id: int
    tier: int
    win_rate_bps: int
    uri: str


def tier_from_win_rate(win_rate: float) -> int:
    if win_rate > 90:
        return 5
    if win_rate > 75:
        return 3
    if win_rate > 50:
        return 2
    return 1


def fetch_arena_agents(api_base: str, limit: int = 100) -> List[Dict[str, Any]]:
    url = f"{api_base.rstrip('/')}/api/telemetry/leaderboard?limit={limit}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        payload = json.loads(resp.read().decode())
    rows = payload.get("rows") or []
    agents = []
    for i, row in enumerate(rows):
        tasks = row.get("tasksCompleted") or int(100 + i * 10)
        rewards = float(row.get("rewardsApn") or 0)
        win_rate = min(99.0, max(1.0, (rewards / 50000.0) * 100.0))
        agents.append(
            {
                "tokenId": i,
                "agentId": row.get("agentId", f"agent-{i}"),
                "winRate": win_rate,
                "tasksCompleted": tasks,
            }
        )
    return agents


def build_plans(agents: List[Dict[str, Any]], week: int, metadata_base: str) -> List[MutationPlan]:
    plans: List[MutationPlan] = []
    for agent in agents:
        token_id = int(agent.get("tokenId", 0))
        win_rate = float(agent.get("winRate", 0))
        tier = tier_from_win_rate(win_rate)
        uri = f"{metadata_base.rstrip('/')}/metadata/agent/{token_id}?tier={tier}&week={week}"
        plans.append(
            MutationPlan(
                token_id=token_id,
                tier=tier,
                win_rate_bps=int(win_rate * 100),
                uri=uri,
            )
        )
    return plans


def mutate_via_cast(plan: MutationPlan, contract: str, rpc: str, pk: str) -> str:
    cmd = [
        "cast",
        "send",
        contract,
        "mutate(uint256,uint8,uint16,string)",
        str(plan.token_id),
        str(plan.tier),
        str(plan.win_rate_bps),
        plan.uri,
        "--rpc-url",
        rpc,
        "--private-key",
        pk,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout)
    return (result.stdout or "").strip()


def run_batch(
    plans: List[MutationPlan],
    *,
    batch_size: int,
    dry_run: bool,
    contract: str,
    rpc: str,
    pk: str,
) -> Dict[str, Any]:
    submitted = 0
    errors: List[str] = []

    for i in range(0, len(plans), batch_size):
        chunk = plans[i : i + batch_size]
        for plan in chunk:
            try:
                if dry_run:
                    print(
                        f"[dry-run] mutate token={plan.token_id} tier={plan.tier} "
                        f"winRateBps={plan.win_rate_bps}"
                    )
                else:
                    tx = mutate_via_cast(plan, contract, rpc, pk)
                    print(f"[live] token={plan.token_id} tx={tx}")
                submitted += 1
            except Exception as exc:  # noqa: BLE001
                errors.append(f"token {plan.token_id}: {exc}")

    return {"submitted": submitted, "total": len(plans), "errors": errors}


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm NFT mutation batch engine")
    parser.add_argument("--week", type=int, default=None, help="Mutation week index")
    parser.add_argument("--batch-size", type=int, default=int(os.getenv("MUTATION_BATCH_SIZE", "20")))
    parser.add_argument("--limit", type=int, default=int(os.getenv("MUTATION_AGENT_LIMIT", "50")))
    args = parser.parse_args(argv)

    api_base = os.getenv("ARENA_API_BASE", os.getenv("YIELDSWARM_API_URL", "http://127.0.0.1:8080"))
    metadata_base = os.getenv("NFT_METADATA_BASE", api_base)
    contract = os.getenv("AGENT_NFT_CONTRACT", "")
    rpc = os.getenv("SEPOLIA_RPC_URL", os.getenv("EVM_RPC_URL", ""))
    pk = os.getenv("SOVEREIGN_PRIVATE_KEY", os.getenv("ORACLE_RELAYER_PRIVATE_KEY", ""))
    dry_run = os.getenv("MUTATION_ENGINE_DRY_RUN", "1") not in ("0", "false", "False")

    week = args.week if args.week is not None else int(os.getenv("MUTATION_WEEK", "0") or 0)

    try:
        agents = fetch_arena_agents(api_base, limit=args.limit)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"Arena API unavailable ({exc}); using synthetic single-agent plan", file=sys.stderr)
        agents = [{"tokenId": 0, "winRate": 55.0, "tasksCompleted": 100}]

    plans = build_plans(agents, week, metadata_base)
    print(f"Built {len(plans)} mutation plan(s) for week {week}")

    if not dry_run and (not contract or not rpc or not pk):
        print("Live mode requires AGENT_NFT_CONTRACT, SEPOLIA_RPC_URL, SOVEREIGN_PRIVATE_KEY", file=sys.stderr)
        return 1

    summary = run_batch(
        plans,
        batch_size=args.batch_size,
        dry_run=dry_run,
        contract=contract,
        rpc=rpc,
        pk=pk,
    )
    print(json.dumps(summary, indent=2))
    return 0 if not summary["errors"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
