"""Tests for cross-chain execution + Great Delta routing."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.cross_chain.great_delta import route_revenue_to_treasury, aggregate_splits
from services.cross_chain.executor import CrossChainExecutor, default_scheduled_jobs
from services.cross_chain.types import StrategyJob, StrategyKind


def test_great_delta_split_sums_to_gross():
    result = route_revenue_to_treasury(1000.0, source="test", strategy="unit")
    split = result["split_usd"]
    total = sum(split.values())
    assert abs(total - 1000.0) < 0.01
    assert split["coreTreasury"] == 500.0
    assert split["growthTreasury"] == 300.0
    assert split["insuranceTreasury"] == 150.0
    assert split["opsTreasury"] == 50.0


def test_aggregate_splits():
    receipts = {
        "a": {"treasury_split": {"split_usd": {"coreTreasury": 50, "growthTreasury": 30, "insuranceTreasury": 15, "opsTreasury": 5}}},
        "b": {"treasury_split": {"split_usd": {"coreTreasury": 100, "growthTreasury": 60, "insuranceTreasury": 30, "opsTreasury": 10}}},
    }
    totals = aggregate_splits(receipts)
    assert totals["coreTreasury"] == 150.0


def test_executor_dry_run_batch(tmp_path, monkeypatch):
    monkeypatch.setenv("RUN_DIR", str(tmp_path))
    monkeypatch.setenv("CROSS_CHAIN_DRY_RUN", "1")
    executor = CrossChainExecutor(dry_run=True)
    jobs = default_scheduled_jobs(shard_id=0)[:2]
    summary = executor.run_batch(jobs)
    assert summary["job_count"] == 2
    assert summary["dry_run"] is True
    assert (tmp_path / "cross-chain-last-run.json").exists()


def test_strategy_kinds_registered():
    jobs = default_scheduled_jobs(shard_id=0)
    kinds = {j.kind for j in jobs}
    assert StrategyKind.SOLANA_LIQUIDITY in kinds
    assert StrategyKind.UNISWAP_V4_HOOK in kinds
    assert StrategyKind.DYDX_PERPS in kinds
    assert StrategyKind.ALTCOIN_POW in kinds
