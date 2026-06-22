"""Shell-level tests for open-metal inference hotload script."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
HOTLOAD = REPO_ROOT / "scripts" / "inference" / "hotload_open_metal_llms.sh"
MATRIX = REPO_ROOT / "config" / "inference" / "open-metal-matrix.json"
LITELLM_CFG = REPO_ROOT / "config" / "inference" / "litellm-open-metal.yaml"


class HotloadOpenMetalScriptTest(unittest.TestCase):
    def test_matrix_and_litellm_config_exist(self) -> None:
        self.assertTrue(MATRIX.is_file())
        self.assertTrue(LITELLM_CFG.is_file())
        text = MATRIX.read_text(encoding="utf-8")
        self.assertIn("outdoor_tomato_impala", text)
        self.assertIn("deepseek-r1:32b", text)

    def test_hotload_script_is_executable(self) -> None:
        self.assertTrue(HOTLOAD.is_file())
        self.assertTrue(os.access(HOTLOAD, os.X_OK))

    def test_dry_run_does_not_use_ollama_run(self) -> None:
        proc = subprocess.run(
            [str(HOTLOAD), "--dry-run"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        combined = proc.stdout + proc.stderr
        self.assertIn("ollama pull", combined.lower())
        self.assertNotIn("ollama run", combined.lower())
        self.assertIn("LiteLLM", combined)

    def test_litellm_config_has_open_metal_models(self) -> None:
        text = LITELLM_CFG.read_text(encoding="utf-8")
        self.assertIn("deepseek-r1-reasoning", text)
        self.assertIn("qwen-tool-fast", text)
        self.assertIn("llama-scout-routing", text)


if __name__ == "__main__":
    unittest.main()
