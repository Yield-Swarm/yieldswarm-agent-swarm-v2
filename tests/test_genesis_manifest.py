"""Genesis Web5 manifest tests."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "config" / "genesis" / "web5-manifest.json"


class GenesisManifestTest(unittest.TestCase):
    def test_manifest_loads(self) -> None:
        data = json.loads(MANIFEST.read_text())
        self.assertEqual(data["motto"], "Not for us. For the next.")
        self.assertIn("web5", data["web_stack"])
        self.assertEqual(len(data["quantum_basis"]["states"]), 4)

    def test_equation_present(self) -> None:
        data = json.loads(MANIFEST.read_text())
        self.assertIn("∇", data["equation"]["symbol"])


if __name__ == "__main__":
    unittest.main()
