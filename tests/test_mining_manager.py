"""Tests for unified mining manager."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from mining.config import load_mining_config
from mining.manager import UnifiedMiningManager


def test_load_mining_config_wallets(monkeypatch):
    monkeypatch.setenv("MINING_ROOT_TAO", "5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF")
    monkeypatch.setenv("MINING_ROOT_BASE_ETC", "0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00")
    monkeypatch.setenv("MONERO_WALLET_ADDRESS", "48edfHu7V9ZHdFZJx8z6u1xGsf6hqYdqaHjwKvVhCg3LvjnrpiYoLFXgsKBkUH51N9AMXw7UXcW9YxM2eHkuKNdnHaMTtCCW2")
    cfg = load_mining_config()
    assert cfg.tao_wallet.startswith("5Gw")
    assert cfg.etc_wallet.startswith("0x")
    assert cfg.monero_wallet.startswith("48")


def test_grass_lineups_from_env(monkeypatch):
    monkeypatch.setenv(
        "GRASS_NODE_KEYS",
        json.dumps(
            [
                {"id": "g1", "platform": "android", "wallet": "grass_wallet_1"},
                {"id": "g2", "platform": "linux", "wallet": "grass_wallet_2"},
            ]
        ),
    )
    cfg = load_mining_config()
    assert len(cfg.grass_lineups) == 2
    assert cfg.grass_lineups[0].multiplier == 3.0
    assert cfg.grass_lineups[1].multiplier == 2.0


def test_manager_dry_run_start(tmp_path, monkeypatch):
    monkeypatch.setenv("MINING_RUN_DIR", str(tmp_path))
    monkeypatch.setenv("MINING_DRY_RUN", "1")
    monkeypatch.setenv("MINING_ROOT_TAO", "5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF")
    monkeypatch.setenv("MONERO_WALLET_ADDRESS", "48edfHu7V9ZHdFZJx8z6u1xGsf6hqYdqaHjwKvVhCg3LvjnrpiYoLFXgsKBkUH51N9AMXw7UXcW9YxM2eHkuKNdnHaMTtCCW2")
    monkeypatch.setenv("MINING_ROOT_BASE_ETC", "0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00")
    monkeypatch.setenv(
        "GRASS_NODE_KEYS",
        json.dumps([{"id": "g1", "platform": "linux", "wallet": "w1"}]),
    )
    monkeypatch.setenv(
        "DEPIN_HELIUM_HOTSPOT_KEYS",
        json.dumps([{"serial": "60013006881", "ssid": "Helium-5G-141C", "wallet": "h1"}]),
    )
    monkeypatch.setenv("BT_NETUID", "1")

    mgr = UnifiedMiningManager()
    result = mgr.start("monero")
    assert result["ok"] is True
    assert result["results"]["monero"]["status"]["state"] == "dry_run"
    assert (tmp_path / "monero-config.json").exists()

    status = mgr.status()
    assert status["total"] == 5
    assert (tmp_path / "mining-manager-status.json").exists()


def test_manager_list_miners():
    mgr = UnifiedMiningManager()
    assert "bittensor" in mgr.list_miners()
    assert "helium" in mgr.list_miners()
