"""Solenoid architecture config validation."""

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class TestSolenoidConfig(unittest.TestCase):
    def test_treasury_manifest_has_iotex_mining_root(self):
        manifest = json.loads((REPO / "config" / "TREASURY_MANIFEST.json").read_text())
        roots = manifest["mining_roots"]
        self.assertIn("iotex", roots)
        self.assertTrue(roots["iotex"].startswith("0x"))
        self.assertEqual(len(roots), 9)

    def test_solenoids_registry_three_chains(self):
        cfg = json.loads((REPO / "config" / "solenoids.json").read_text())
        self.assertEqual(cfg["max_agents"], 521)
        ids = {s["id"] for s in cfg["solenoids"]}
        self.assertEqual(ids, {"nexus", "helix", "shadow"})

    def test_vault_policies_exist(self):
        for name in ("nexus-runtime", "helix-runtime", "shadow-runtime"):
            path = REPO / "vault" / "policies" / f"{name}.hcl"
            self.assertTrue(path.is_file(), f"missing {path}")


if __name__ == "__main__":
    unittest.main()
