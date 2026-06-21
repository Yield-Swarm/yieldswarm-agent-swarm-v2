"""Tests for Node 5 Stellar + Cosmos integration."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from nodes.node5.config import Node5Config, StellarConfig, CosmosConfig, load_node5_config
from nodes.node5.orchestrator import Node5Orchestrator, run_cycle
from services.cross_chain.executor import default_scheduled_jobs
from services.cross_chain.types import StrategyKind


def test_load_node5_config_defaults(monkeypatch):
    monkeypatch.delenv("STELLAR_SECRET_KEY", raising=False)
    monkeypatch.setenv("NODE5_DRY_RUN", "1")
    cfg = load_node5_config()
    assert cfg.dry_run is True
    assert cfg.stellar.network in ("public", "testnet")


def test_node5_orchestrator_status_cycle():
    cfg = Node5Config(
        enabled=True,
        dry_run=True,
        stellar=StellarConfig(enabled=True, public_key="G_TEST"),
        cosmos=CosmosConfig(enabled=True, chain_id="akashnet-2"),
        actions=["status"],
    )
    orch = Node5Orchestrator(config=cfg)
    report = orch.run_cycle()
    assert report["ok"] is True
    assert "status" in report["results"]
    assert report["results"]["status"]["stellar"]["chain"] == "stellar"


def test_run_cycle_persists(tmp_path, monkeypatch):
    monkeypatch.setenv("NODE5_DRY_RUN", "1")
    monkeypatch.setenv("RUN_DIR", str(tmp_path))
    report = run_cycle(actions=["status", "balance"], run_dir=tmp_path)
    assert report["ok"] is True
    assert (tmp_path / "node5-last-run.json").exists()


def test_stellar_cosmos_strategy_registered():
    jobs = default_scheduled_jobs(shard_id=0)
    kinds = {j.kind for j in jobs}
    assert StrategyKind.STELLAR_COSMOS in kinds


def test_stellar_payment_dry_run():
    cfg = Node5Config(
        dry_run=True,
        stellar=StellarConfig(destination="G_DEST", public_key="G_SRC", secret_key="S_SRC"),
    )
    from nodes.node5.stellar.client import StellarClient

    client = StellarClient(cfg.stellar, dry_run=True)
    result = client.submit_payment(amount="10", destination="G_DEST")
    assert result.ok is True
    assert result.dry_run is True
    assert result.tx_hash == "dry-run-stellar-payment"
