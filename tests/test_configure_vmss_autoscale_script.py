"""Shell-level tests for configure-vmss-autoscale.sh."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "azure" / "configure-vmss-autoscale.sh"
GPU_METRICS = REPO_ROOT / "scripts" / "azure" / "gpu-metrics-agent.sh"
ENV_EXAMPLE = REPO_ROOT / "deploy" / "azure-mainnet.env.example"


class ConfigureVmssAutoscaleScriptTest(unittest.TestCase):
    def test_script_is_executable(self) -> None:
        self.assertTrue(SCRIPT.is_file())
        self.assertTrue(os.access(SCRIPT, os.X_OK))

    def test_env_example_has_autoscale_vars(self) -> None:
        text = ENV_EXAMPLE.read_text(encoding="utf-8")
        self.assertIn("AZURE_AUTOSCALE_SCALE_OUT_CPU=75", text)
        self.assertIn("AZURE_VMSS_SCALE_IN_POLICY=OldestVM", text)
        self.assertIn("AZURE_AUTOSCALE_PREDICTIVE_MODE=ForecastOnly", text)

    def test_dry_run_prints_planned_commands(self) -> None:
        proc = subprocess.run(
            [str(SCRIPT), "--dry-run", "--env", str(ENV_EXAMPLE)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        combined = proc.stdout + proc.stderr
        self.assertIn("Percentage CPU > 75", combined)
        self.assertIn("Percentage CPU < 30", combined)
        self.assertIn("OldestVM", combined)
        self.assertIn("ForecastOnly", combined)
        self.assertIn("business-hours", combined)

    def test_gpu_metrics_script_exists(self) -> None:
        self.assertTrue(GPU_METRICS.is_file())


if __name__ == "__main__":
    unittest.main()
