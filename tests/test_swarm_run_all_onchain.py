"""Tests for 16-node Termux → RunPod swarm launcher."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = REPO_ROOT / "scripts" / "swarm" / "run-all-onchain.sh"
MATRIX = REPO_ROOT / "config" / "swarm" / "16-node-matrix.json"
WORKER = REPO_ROOT / "scripts" / "swarm" / "helix-runpod-worker.js"


class SwarmRunAllOnchainTest(unittest.TestCase):
    def test_matrix_has_16_nodes(self) -> None:
        import json

        data = json.loads(MATRIX.read_text(encoding="utf-8"))
        self.assertEqual(len(data["nodes"]), 16)
        self.assertEqual(data["stagger_sec"], 3)

    def test_launcher_requires_node_id(self) -> None:
        env = os.environ.copy()
        env.pop("SWARM_NODE_ID", None)
        proc = subprocess.run(
            [str(LAUNCHER), "--dry-run"],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("SWARM_NODE_ID", proc.stderr or proc.stdout)

    def test_dry_run_stagger_for_node_8(self) -> None:
        proc = subprocess.run(
            [str(LAUNCHER), "--dry-run"],
            cwd=REPO_ROOT,
            env={**os.environ, "SWARM_NODE_ID": "8"},
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        self.assertIn("stagger sleep 21s", proc.stdout)

    def test_worker_script_exists(self) -> None:
        self.assertTrue(WORKER.is_file())


if __name__ == "__main__":
    unittest.main()
