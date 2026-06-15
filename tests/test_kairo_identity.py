"""Kairo identity round-trip tests."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from kairo.identity.verify import sign_telemetry_event, verify_telemetry_event
from kairo.identity.wallet import generate_driver_identity, save_registry, load_registry
from kairo.telemetry.ingest import ingest_signed_event


def test_register_sign_verify_ingest(tmp_path, monkeypatch):
    reg = tmp_path / "registry.json"
    monkeypatch.setattr("kairo.identity.wallet._REGISTRY_PATH", reg)
    monkeypatch.setattr("kairo.telemetry.ingest._EVENTS_PATH", tmp_path / "events.jsonl")
    monkeypatch.setattr("kairo.telemetry.ingest._CONTRIBUTIONS_PATH", tmp_path / "contrib.json")

    identity, priv = generate_driver_identity(device_fingerprint="test")
    save_registry({identity.driver_id: identity.to_dict()})

    event = sign_telemetry_event(
        priv,
        identity.driver_id,
        identity.evm_address,
        "drive.segment",
        {"latitude": 37.77, "longitude": -122.42, "speed_mph": 30, "miles": 1.0},
        nonce="nonce-abc-123",
        timestamp="2026-06-15T12:00:00+00:00",
    )
    ok, err = verify_telemetry_event(event)
    assert ok, err

    ingested, ierr = ingest_signed_event(event)
    assert ingested is not None, ierr
    assert ingested.tree_of_life_shard.startswith("tol-shard-")
