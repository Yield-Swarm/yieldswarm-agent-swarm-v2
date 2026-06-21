"""Shell-level tests for deploy-ipfs-blockchain.sh improvements."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "deploy-ipfs-blockchain.sh"
BIFROST_LIB = REPO_ROOT / "scripts" / "lib" / "bifrost_pin.py"
DEPLOY_LOG = REPO_ROOT / ".run" / "deployment.log"


class DeployIpfsBlockchainScriptTest(unittest.TestCase):
    def test_bifrost_lib_uses_underscore_naming(self) -> None:
        self.assertTrue(BIFROST_LIB.is_file())
        self.assertEqual(BIFROST_LIB.name, "bifrost_pin.py")
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('BIFROST_LIB="${SCRIPT_DIR}/lib/bifrost_pin.py"', text)
        self.assertNotIn("bifrost-pin.py", text)

    def test_script_is_executable(self) -> None:
        self.assertTrue(os.access(SCRIPT, os.X_OK))

    def test_dry_run_writes_deployment_log(self) -> None:
        if DEPLOY_LOG.exists():
            DEPLOY_LOG.unlink()
        proc = subprocess.run(
            [str(SCRIPT), "--dry-run", "--skip-build"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        self.assertTrue(DEPLOY_LOG.is_file())
        log_text = DEPLOY_LOG.read_text(encoding="utf-8")
        self.assertIn("dry-run plan", log_text.lower())
        self.assertIn("final validation passed", log_text.lower())

    def test_dry_run_prints_resolved_paths(self) -> None:
        proc = subprocess.run(
            [str(SCRIPT), "--dry-run", "--skip-build"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        self.assertIn("SCRIPT_DIR", proc.stdout)
        self.assertIn("BIFROST_LIB", proc.stdout)
        self.assertIn("DRY-RUN PLAN", proc.stdout)


if __name__ == "__main__":
    unittest.main()
