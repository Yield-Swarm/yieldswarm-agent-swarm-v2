"""Tests for scripts/telemetry/sys_profile.py"""
import json
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "telemetry" / "sys_profile.py"


class TestSysProfile(unittest.TestCase):
    def test_runs_and_emits_json(self):
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--json", "--no-snapshot"],
            capture_output=True,
            text=True,
            check=True,
            cwd=REPO_ROOT,
        )
        data = json.loads(proc.stdout)
        self.assertEqual(data["recipient"], "Justas | CherryServers")
        self.assertIn("cpu", data)
        self.assertIn("memory", data)
        self.assertIn("storage", data)
        self.assertIn("utilization_30d", data)
        self.assertIn("logical_cores", data["cpu"])

    def test_runs_markdown(self):
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--no-snapshot"],
            capture_output=True,
            text=True,
            check=True,
            cwd=REPO_ROOT,
        )
        self.assertIn("Cherry Servers", proc.stdout)
        self.assertIn("Metric Feature", proc.stdout)


if __name__ == "__main__":
    unittest.main()
