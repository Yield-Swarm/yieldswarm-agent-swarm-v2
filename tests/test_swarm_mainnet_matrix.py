"""Tests for swarm mainnet matrix modules."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MAINNET = REPO_ROOT / "scripts" / "swarm" / "mainnet-matrix.ts"
CONSENSUS = REPO_ROOT / "scripts" / "swarm" / "run-consensus-audit.sh"


class SwarmMainnetTest(unittest.TestCase):
    def test_mainnet_files_exist(self) -> None:
        for name in ("meshDriver.ts", "runpodBridge.ts", "syncNetwork.ts"):
            self.assertTrue((REPO_ROOT / "scripts" / "swarm" / "lib" / name).is_file())
        self.assertTrue(MAINNET.is_file())

    def test_package_has_swarm_scripts(self) -> None:
        text = (REPO_ROOT / "package.json").read_text(encoding="utf-8")
        self.assertIn('"swarm:mainnet"', text)
        self.assertIn('"swarm:consensus"', text)
        self.assertIn('"run-all-onchain"', text)

    def test_consensus_script_uses_expanded_status(self) -> None:
        text = CONSENSUS.read_text(encoding="utf-8")
        self.assertIn('STATUS="SUCCESS"', text)
        self.assertIn("* Pipeline Status: ${STATUS}", text)
        self.assertNotIn("<< 'REPORT_EOF'", text)

    def test_mainnet_matrix_runs(self) -> None:
        proc = subprocess.run(
            ["npm", "run", "swarm:mainnet"],
            cwd=REPO_ROOT,
            env={**os.environ, "SWARM_NODE_ID": "3"},
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        self.assertIn("STATE MATRICES SYNCHRONIZED", proc.stdout)
        reports = list((REPO_ROOT / "reports").glob("consensus_run_*.md"))
        self.assertTrue(reports, "expected consensus report file")


if __name__ == "__main__":
    unittest.main()
