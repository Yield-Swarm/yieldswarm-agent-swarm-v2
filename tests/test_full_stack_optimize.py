"""Full-stack optimization script tests."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def test_bid_optimizer_dry_run():
    script = REPO / "akash" / "bid-optimizer.py"
    out = subprocess.run(
        [sys.executable, str(script), "--gpu", "h100", "--target-apr", "40", "--max-bid", "85000", "--dry-run"],
        capture_output=True,
        text=True,
        check=True,
        cwd=REPO,
    )
    data = json.loads(out.stdout)
    assert data["gpu"] == "h100"
    assert 50_000 <= data["recommended_bid_uakt"] <= 95_000


def test_sovereign_status_flag():
    run_py = REPO / "iteration-100" / "run.py"
    out = subprocess.run(
        [sys.executable, str(run_py), "--status"],
        capture_output=True,
        text=True,
        check=True,
        cwd=REPO,
    )
    data = json.loads(out.stdout)
    assert "status" in data


def test_telemetry_daemon_once():
    script = REPO / "kairo" / "telemetry_daemon.py"
    out = subprocess.run(
        [sys.executable, str(script), "--once", "--dry-run", "--helium", "--nexus"],
        capture_output=True,
        text=True,
        check=True,
        cwd=REPO,
    )
    data = json.loads(out.stdout.strip().splitlines()[-1])
    assert data.get("dry_run") is True
