"""Tests for GEOD scheduler."""

from services.geod.scheduler import run_geod_tick


def test_geod_tick_writes_state():
    report = run_geod_tick()
    assert report["ok"] is True
    assert "coordinate" in report
    assert "shard_id" in report["coordinate"]
