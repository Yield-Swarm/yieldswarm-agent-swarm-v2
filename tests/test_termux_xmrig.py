"""Tests for Termux XMRig status aggregation."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_xmrig_status_writes_json(tmp_path, monkeypatch):
    """Status script writes schema even when miners are offline."""
    monkeypatch.setenv("XMRIG_INSTANCES", "2")
    monkeypatch.setenv("XMRIG_HTTP_PORT_BASE", "18081")
    out = tmp_path / "termux-xmrig"
    monkeypatch.setattr(
        "pathlib.Path.mkdir",
        lambda self, *a, **k: None,
    )
    proc = subprocess.run(
        ["bash", "scripts/termux/xmrig-status.sh"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0
    state_path = REPO_ROOT / ".data/termux-xmrig/latest.json"
    if state_path.exists():
        state = json.loads(state_path.read_text(encoding="utf-8"))
        assert state["schemaVersion"] == "termux-xmrig/v1"
        assert state["instances"] == 2
