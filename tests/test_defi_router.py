"""Tests for YieldSwarm DeFiRouter agent."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.cross_chain.defi_router.agent import DeFiRouterAgent
from services.cross_chain.defi_router.circuit_breaker import CircuitBreaker
from services.cross_chain.defi_router.models import Portfolio
from services.cross_chain.defi_router.router import RouteOptimizer
from services.cross_chain.defi_router.sensitivity import min_viable_portfolio, sensitivity_analysis


def test_default_portfolio_value():
    assert Portfolio.yieldswarm_default().total_usd == 32.50


def test_arbitrum_hub_fees_at_baseline():
    optimizer = RouteOptimizer()
    best = optimizer.best_route(Portfolio.yieldswarm_default())
    assert best.strategy_id == "arbitrum_hub"
    assert best.total_fees_usd == pytest.approx(12.72, abs=0.01)
    assert best.fee_pct == pytest.approx(39.1, abs=0.2)
    assert best.retention_pct == pytest.approx(60.9, abs=0.3)
    assert best.net_output_usd == pytest.approx(19.78, abs=0.05)


def test_circuit_breaker_triggers_on_small_portfolio():
    optimizer = RouteOptimizer()
    best = optimizer.best_route(Portfolio.yieldswarm_default())
    cb = CircuitBreaker(threshold_pct=30.0).evaluate(best, 32.50)
    assert cb.triggered is True
    assert "WAIT" in cb.recommendation


def test_sensitivity_viable_at_50_plus():
    rows = sensitivity_analysis([32.5, 50, 100])
    at_32 = next(r for r in rows if r["portfolioUsd"] == 32.5)
    at_50 = next(r for r in rows if r["portfolioUsd"] == 50)
    assert at_32["viable"] is False
    assert at_50["viable"] is True


def test_min_viable_portfolio_near_50():
    assert 45 <= min_viable_portfolio() <= 55


def test_agent_writes_state(tmp_path):
    agent = DeFiRouterAgent(dry_run=True, state_dir=tmp_path)
    result = agent.run()
    assert result["status"] == "HALTED"
    assert (tmp_path / "latest.json").exists()
    assert (tmp_path / "execution_report.txt").exists()
    state = json.loads((tmp_path / "latest.json").read_text())
    assert state["bestRoute"]["strategyId"] == "arbitrum_hub"


def test_providers_whitelist_count():
    from services.cross_chain.defi_router.providers import list_providers

    providers = list_providers()
    assert len(providers) == 7
