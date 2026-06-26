"""Tests for Helix duadilateral route config."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from services.cross_chain.helix_bilateral import load_routes_config, tick_duadilateral_routes

REPO_ROOT = Path(__file__).resolve().parents[1]
ROUTES_FILE = REPO_ROOT / "config" / "helix" / "chain-routes.json"


class HelixDuadilateralRoutesTest(unittest.TestCase):
    def test_config_targets(self) -> None:
        cfg = load_routes_config()
        self.assertEqual(set(cfg["targets"].keys()), {"base", "ethereum", "ton", "tao", "avax"})

    def test_all_sources_have_routes_to_all_targets(self) -> None:
        cfg = load_routes_config()
        sources = set(cfg["sources"].keys())
        targets = set(cfg["targets"].keys())
        pairs = {(r["source"], r["target"]) for r in cfg["duadilaterals"]}
        for source in sources:
            for target in targets:
                self.assertIn((source, target), pairs, f"missing {source}↔{target}")

    def test_tick_writes_summary(self) -> None:
        summary = tick_duadilateral_routes(dry_run=True)
        self.assertEqual(summary["route_count"], 15)
        self.assertTrue(summary["dry_run"])
        out = REPO_ROOT / ".run" / "helix-duadilateral-last-run.json"
        self.assertTrue(out.exists())
        data = json.loads(out.read_text())
        self.assertEqual(data["route_count"], 15)


if __name__ == "__main__":
    unittest.main()
