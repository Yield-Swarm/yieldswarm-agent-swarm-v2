"""Tests for Termux edge mining fleet (8 instances)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_termux_fleet_eight_instances(monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setenv("TERMUX_INSTANCE_COUNT", "8")
    monkeypatch.setenv("TERMUX_RUN_DIR", str(tmp_path / "termux"))
    monkeypatch.setenv("MINING_DRY_RUN", "1")

    from mining.termux_fleet import TermuxFleet

    fleet = TermuxFleet()
    inst = fleet.instances()
    assert len(inst) == 8
    assert inst[0].ram_mb == 16384
    assert inst[0].storage_gb == 128
    coins = [i.coin for i in inst]
    assert coins[0] == "prl"
    assert "grass" in coins
    assert "monero" in coins


def test_termux_fleet_launch_dry_run(monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setenv("TERMUX_INSTANCE_COUNT", "8")
    monkeypatch.setenv("TERMUX_RUN_DIR", str(tmp_path / "termux"))
    monkeypatch.setenv("MINING_DRY_RUN", "1")

    from mining.termux_fleet import TermuxFleet

    result = TermuxFleet().launch(dry_run=True)
    assert result["ok"] is True
    assert result["instanceCount"] == 8
    assert len(result["results"]) == 8

    state_path = Path(result["statePath"])
    state = json.loads(state_path.read_text(encoding="utf-8"))
    assert state["schemaVersion"] == "termux-fleet/v1"
    assert len(state["instances"]) == 8
