"""Tests for four-swarm helical architecture scaffolds."""

from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def test_helical_schemas_exist():
    schema_dir = REPO / "schemas" / "helical"
    expected = [
        "envelope.v1.json",
        "state-contract.v1.json",
        "physical-core.v1.json",
        "mining-pools.v1.json",
        "marketplace.v1.json",
        "mmorpg.v1.json",
    ]
    for name in expected:
        assert (schema_dir / name).exists()


def test_physical_core_snapshot_shape():
    from swarms.physical_core.engines.telemetry_engine import PhysicalCoreTelemetryEngine

    snap = PhysicalCoreTelemetryEngine().capture_snapshot()
    assert snap["schemaVersion"] == "physical-core/v1"
    assert snap["siteId"] == "carrizozo-nm-10ac"
    assert snap["solar"]["arrayKwPeak"] == 27
    assert snap["asics"]["fleetSize"] == 30
    assert len(snap["edge"]["nodes"]) >= 1


def test_mining_pools_handoff():
    from swarms.mining_pools.engines.pool_router import ingest_physical_core

    state = ingest_physical_core()
    assert state["schemaVersion"] == "mining-pools/v1"
    assert state["attribution"]["treasurySplit"] == "50,30,15,5"


def test_helical_state_contract():
    state_path = REPO / "dashboard" / "helical-state.json"
    state = json.loads(state_path.read_text())
    assert state["schemaVersion"] == "helical-state/v1"
    assert set(state["swarms"]) == {"physical-core", "mining-pools", "marketplace", "mmorpg"}


if __name__ == "__main__":
    test_helical_schemas_exist()
    test_physical_core_snapshot_shape()
    test_mining_pools_handoff()
    test_helical_state_contract()
    print("all tests passed")
