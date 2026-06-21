"""Cross-chain strategy executor — cron + Sovereign Loop integration."""

from __future__ import annotations

import json
import os
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from services.cross_chain.great_delta import aggregate_splits
from services.cross_chain.strategies import STRATEGY_REGISTRY
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob, StrategyKind

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


STATE_FILE_NAME = "cross-chain-executions.json"


class CrossChainExecutor:
    """Runs configured strategies and persists receipts for telemetry."""

    def __init__(self, *, dry_run: Optional[bool] = None):
        if dry_run is None:
            dry_run = os.getenv("CROSS_CHAIN_DRY_RUN", "1").lower() in ("1", "true", "yes")
        self.dry_run = dry_run
        _run_dir().mkdir(parents=True, exist_ok=True)

    def run_job(self, job: StrategyJob) -> ExecutionReceipt:
        kind = job.kind.value if isinstance(job.kind, StrategyKind) else str(job.kind)
        cls = STRATEGY_REGISTRY.get(kind)
        if not cls:
            return ExecutionReceipt(
                job_id=job.id,
                kind=job.kind,
                status=ExecutionStatus.FAILED,
                error=f"unknown strategy kind: {kind}",
            )
        strategy = cls()
        receipt = strategy.execute(job)
        self._persist_receipt(receipt)
        return receipt

    def run_batch(self, jobs: List[StrategyJob]) -> Dict[str, Any]:
        receipts: Dict[str, Any] = {}
        for job in jobs:
            r = self.run_job(job)
            receipts[job.id] = r.to_dict()

        totals = aggregate_splits(receipts)
        summary = {
            "run_at": int(time.time()),
            "dry_run": self.dry_run,
            "job_count": len(jobs),
            "treasury_totals_usd": totals,
            "receipts": receipts,
        }
        self._write_summary(summary)
        return summary

    def _persist_receipt(self, receipt: ExecutionReceipt) -> None:
        state_file = _run_dir() / STATE_FILE_NAME
        existing: Dict[str, Any] = {}
        if state_file.exists():
            try:
                existing = json.loads(state_file.read_text())
            except json.JSONDecodeError:
                existing = {}
        existing[receipt.job_id] = receipt.to_dict()
        # Keep last 200 receipts
        if len(existing) > 200:
            keys = sorted(existing.keys())[-200:]
            existing = {k: existing[k] for k in keys}
        state_file.write_text(json.dumps(existing, indent=2))

    def _write_summary(self, summary: Dict[str, Any]) -> None:
        path = _run_dir() / "cross-chain-last-run.json"
        path.write_text(json.dumps(summary, indent=2))


def default_scheduled_jobs(*, shard_id: int = 0) -> List[StrategyJob]:
    """Default strategy batch for sovereign tick / cron shard."""
    prefix = f"shard{shard_id}"
    dry = os.getenv("CROSS_CHAIN_DRY_RUN", "1").lower() in ("1", "true", "yes")

    return [
        StrategyJob(
            id=f"{prefix}-solana-{uuid.uuid4().hex[:8]}",
            kind=StrategyKind.SOLANA_LIQUIDITY,
            params={"action": "swap", "amount": 0.1, "expected_yield_bps": 15},
            dry_run=dry,
            cron_shard=shard_id,
        ),
        StrategyJob(
            id=f"{prefix}-uniswap-{uuid.uuid4().hex[:8]}",
            kind=StrategyKind.UNISWAP_V4_HOOK,
            params={"auction_type": "dutch", "notional_usd": 1000, "expected_yield_bps": 25},
            dry_run=dry,
            cron_shard=shard_id,
        ),
        StrategyJob(
            id=f"{prefix}-dydx-{uuid.uuid4().hex[:8]}",
            kind=StrategyKind.DYDX_PERPS,
            params={"action": "hedge", "market": "BTC-USD", "size_usd": 500, "expected_pnl_bps": 5},
            dry_run=dry,
            cron_shard=shard_id,
        ),
        StrategyJob(
            id=f"{prefix}-pow-{uuid.uuid4().hex[:8]}",
            kind=StrategyKind.ALTCOIN_POW,
            params={"coin": "bittensor", "action": "status", "estimated_daily_usd": 0},
            dry_run=dry,
            cron_shard=shard_id,
        ),
        StrategyJob(
            id=f"{prefix}-node5-{uuid.uuid4().hex[:8]}",
            kind=StrategyKind.STELLAR_COSMOS,
            params={"action": "status", "gross_revenue_usd": 0},
            dry_run=dry,
            cron_shard=shard_id,
        ),
    ]


def run_scheduled_strategies(*, shard_id: Optional[int] = None) -> Dict[str, Any]:
    """Entrypoint for agents/cross_chain_executor.py and cron."""
    shard = shard_id if shard_id is not None else int(os.getenv("AGENT_SHARD_ID", "0"))
    executor = CrossChainExecutor()
    return executor.run_batch(default_scheduled_jobs(shard_id=shard))
