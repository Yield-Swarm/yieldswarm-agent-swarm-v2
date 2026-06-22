"""Tests for swarm elevator launch wiring."""

import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


class SwarmElevatorsTest(unittest.TestCase):
    def setUp(self):
        self._env = os.environ.copy()
        os.environ["SWARM_API_KEY_PRIMARY"] = "test-primary-key"
        os.environ["SWARM_API_KEY_BACKEND"] = "test-backend-key"

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)

    def test_book_roots_count(self):
        from yieldswarm.book_roots import load_book_roots

        roots = load_book_roots()
        self.assertEqual(len(roots), 14)
        self.assertEqual(roots[0].key, "root_01_genesis")
        self.assertEqual(roots[-1].key, "root_14_mainnet")

    def test_auth_fallback(self):
        from yieldswarm.auth import resolve_backend_key, resolve_primary_key

        del os.environ["SWARM_API_KEY_PRIMARY"]
        os.environ["AGENTSWARM_MASTER_KEY"] = "fallback-master"
        self.assertEqual(resolve_primary_key(), "fallback-master")

        del os.environ["SWARM_API_KEY_BACKEND"]
        os.environ["YIELDSWARM_ROUTER_API_KEY"] = "router-key"
        self.assertEqual(resolve_backend_key(), "router-key")

    def test_core_once(self):
        proc = subprocess.run(
            [
                sys.executable,
                "-m",
                "yieldswarm.core",
                "--root",
                "root_01_genesis",
                "--node-id",
                "1",
                "--auth",
                "test-primary-key",
                "--once",
            ],
            cwd=REPO_ROOT,
            env={**os.environ, "PYTHONPATH": str(REPO_ROOT)},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("elevator_start", proc.stdout)
        self.assertIn("heartbeat", proc.stdout)

    def test_network_once(self):
        proc = subprocess.run(
            [
                sys.executable,
                "-m",
                "yieldswarm.network",
                "--swarm-mode",
                "elisazos",
                "--key",
                "test-primary-key",
                "--once",
            ],
            cwd=REPO_ROOT,
            env={**os.environ, "PYTHONPATH": str(REPO_ROOT)},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("swarm_sync", proc.stdout)


if __name__ == "__main__":
    unittest.main()
