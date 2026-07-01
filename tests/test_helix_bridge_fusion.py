"""Tests for Heaven-Earth helix bridge fusion sync."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from mmorpg.helix_dashboard import helix_bridge


class HelixBridgeFusionTests(unittest.TestCase):
    def test_map_earth_state_merges_artifacts(self) -> None:
        massive = {
            "updatedAt": "2026-07-01T17:08:36+00:00",
            "cloudVmsPlanned": 90,
            "blockers": ["aws-not-authenticated"],
            "energy": {"solarSurplusKw": 12.4, "hydroOnline": True},
            "miningFleet": {
                "localXmr": True,
                "walletBlockers": ["wallet-ZANO"],
            },
        }
        pools = {"poolsRunning": 2, "localXmr": True}
        earth = helix_bridge.map_earth_state(massive, pools)
        self.assertTrue(earth["localXmr"])
        self.assertEqual(earth["poolsRunning"], 2)
        self.assertEqual(earth["cloudVmsPlanned"], 90)
        self.assertIn("aws-not-authenticated", earth["blockers"])
        self.assertIn("wallet-ZANO", earth["blockers"])

    def test_fusion_sync_writes_helix_and_handoff_bus(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "yield-swarm-core" / "shared-state.json"
            massive = root / "artifacts" / "cloud-mining" / "massive-stack-status.json"
            pools = root / "artifacts" / "all-pools-status.json"
            helix_state = root / "dashboard" / "helix-state.json"

            shared.parent.mkdir(parents=True)
            shared.write_text('{"heavenEarth":{"helix":{"tick":0}}}\n')
            massive.parent.mkdir(parents=True)
            massive.write_text(
                json.dumps(
                    {
                        "cloudVmsPlanned": 10,
                        "blockers": [],
                        "energy": {"solarSurplusKw": 1, "hydroOnline": False},
                        "miningFleet": {"localXmr": False, "walletBlockers": []},
                    }
                )
            )
            pools.write_text(json.dumps({"poolsRunning": 1, "localXmr": False}))
            helix_state.parent.mkdir(parents=True, exist_ok=True)
            helix_state.write_text(json.dumps({"phase": "genesis-active", "activated": True}))

            with patch.object(helix_bridge, "REPO_ROOT", root), patch.object(
                helix_bridge, "SHARED_STATE_PATH", shared
            ), patch.object(helix_bridge, "MASSIVE_STACK_PATH", massive), patch.object(
                helix_bridge, "ALL_POOLS_PATH", pools
            ), patch.object(helix_bridge, "HELIX_STATE_PATH", helix_state), patch.object(
                helix_bridge, "_helix_from_api", return_value={}
            ):
                result = helix_bridge.fusion_sync(fetch_api=False)

            self.assertEqual(result["heavenEarth"]["helix"]["tick"], 1)
            self.assertTrue(result["heavenEarth"]["handoffBus"]["synced"])
            self.assertIn("fusion sync OK", result["heavenEarth"]["handoffBus"]["lastMessage"])


if __name__ == "__main__":
    unittest.main()
