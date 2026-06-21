"""Multi-cloud resource manager — Nexus orchestrates Akash, Azure, Vast.ai, RunPod."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
MULTICLOUD_DIR = REPO_ROOT / "scripts" / "multicloud"
WORKLOADS = REPO_ROOT / "config" / "multicloud" / "workloads.yaml"


class MultiCloudManager:
    def __init__(self, dry_run: bool | None = None):
        self.dry_run = dry_run if dry_run is not None else os.environ.get("NEXUS_MULTICLOUD_DRY_RUN", "1") == "1"

    def list_providers(self) -> list[str]:
        return ["akash", "azure", "vast", "runpod", "gcp", "aws", "alibaba"]

    def launch(self, provider: str, workload: str = "gpu-worker") -> dict[str, Any]:
        script = MULTICLOUD_DIR / "launch-worker.sh"
        if not script.is_file():
            return {"ok": False, "error": f"missing {script}"}
        if self.dry_run:
            return {"ok": True, "dry_run": True, "provider": provider, "workload": workload}
        env = {**os.environ, "PROVIDER": provider, "WORKLOAD": workload}
        proc = subprocess.run(
            ["bash", str(script)],
            capture_output=True,
            text=True,
            timeout=600,
            env=env,
            cwd=str(REPO_ROOT),
        )
        return {
            "ok": proc.returncode == 0,
            "provider": provider,
            "workload": workload,
            "stdout": proc.stdout[-2000:],
            "stderr": proc.stderr[-2000:],
        }

    def teardown(self, provider: str) -> dict[str, Any]:
        script = MULTICLOUD_DIR / "teardown-worker.sh"
        if self.dry_run:
            return {"ok": True, "dry_run": True, "action": "teardown", "provider": provider}
        proc = subprocess.run(
            ["bash", str(script)],
            capture_output=True,
            text=True,
            timeout=300,
            env={**os.environ, "PROVIDER": provider},
            cwd=str(REPO_ROOT),
        )
        return {"ok": proc.returncode == 0, "provider": provider, "stderr": proc.stderr[-1000:]}

    def status(self) -> dict[str, Any]:
        tick = REPO_ROOT / ".run" / "cloud-scheduler-last-tick.json"
        last_tick = None
        if tick.is_file():
            last_tick = json.loads(tick.read_text(encoding="utf-8"))
        return {
            "providers": self.list_providers(),
            "dry_run": self.dry_run,
            "workloads_config": str(WORKLOADS),
            "last_scheduler_tick": last_tick,
        }
