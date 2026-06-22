"""Tests for Helix Nodes lottery + registry."""

import os
import tempfile
from pathlib import Path

import pytest

from services.helix_nodes.store import HelixNodeStore


@pytest.fixture
def store(tmp_path, monkeypatch):
    monkeypatch.setenv("HELIX_NODES_DRY_RUN", "1")
    monkeypatch.setenv("HELIX_NODES_TICKETS_PER_HOUR", "2")
    return HelixNodeStore(root=tmp_path)


def test_register_and_heartbeat(store):
    node = store.register()
    assert node["node_id"].startswith("hn-")
    assert node["lottery_tickets"] == 1

    updated = store.heartbeat(node["node_id"])
    assert updated["status"] == "online"
    assert updated["lottery_tickets"] >= 1


def test_referral_bonus(store):
    a = store.register()
    b = store.register(referral_code=a["referral_code"])
    assert b["referred_by"] == a["node_id"]
    refreshed = store.get(a["node_id"])
    assert refreshed["referral_count"] == 1
    assert refreshed["lottery_tickets"] >= 6  # 1 initial + 5 referral


def test_action_bonus(store):
    node = store.register()
    out = store.record_action(node["node_id"], "share")
    assert out["lottery_tickets"] == 3  # 1 initial + 2 share bonus


def test_lottery_draw_simulated(store):
    store.register()
    draw = store.lottery_draw()
    assert draw["simulated"] is True
    assert "winners" in draw
