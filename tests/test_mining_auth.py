"""Tests for mining auth and reward routing."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from mining.auth import MiningAuthService
from mining.rewards import RewardRouter
from mining.fleet import FleetRegistry


def test_auth_dev_skip(monkeypatch):
    monkeypatch.setenv("MINING_AUTH_SKIP", "1")
    auth = MiningAuthService()
    ctx = auth.bootstrap_context()
    assert ctx.ok is True
    token = auth.issue_token("test-1", "local")
    assert auth.verify_token(token, "test-1", "local") is True


def test_auth_hmac_roundtrip(monkeypatch):
    monkeypatch.delenv("MINING_AUTH_SKIP", raising=False)
    monkeypatch.setenv("AGENTSWARM_MASTER_KEY", "test-master-key-for-mining-auth")
    auth = MiningAuthService()
    token = auth.issue_token("akash-1", "akash")
    assert auth.verify_token(token, "akash-1", "akash") is True
    assert auth.verify_token(token, "wrong", "akash") is False


def test_reward_router_wallets(monkeypatch):
    monkeypatch.setenv("MINING_ROOT_TAO", "5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF")
    monkeypatch.setenv("NEXUS_TREASURY_SOLANA", "kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN")
    monkeypatch.setenv("MINING_ROOT_BASE_ETC", "0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00")
    router = RewardRouter()
    assert router.get_wallet("tao").startswith("5Gw")
    assert router.get_wallet("sol").startswith("kuT")
    assert router.get_wallet("etc").startswith("0x")


def test_fleet_default_instances(monkeypatch):
    monkeypatch.setenv("MINING_AUTH_SKIP", "1")
    monkeypatch.delenv("MINING_FLEET_INSTANCES", raising=False)
    fleet = FleetRegistry()
    assert len(fleet.instances) >= 1
    result = fleet.connect_all()
    assert result["ok"] is True
