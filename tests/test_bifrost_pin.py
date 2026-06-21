"""Tests for Bifröst IPFS bridge manifest."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "lib"))

from bifrost_pin import build_manifest, default_realms, write_dashboard_config  # noqa: E402


class BifrostManifestTest(unittest.TestCase):
    def test_default_realms_map_blockchain_hosts(self) -> None:
        realms = default_realms("bafytest", "https://gateway.example/ipfs")
        self.assertIn("helixchain.blockchain", realms)
        self.assertIn("command-center", realms["helixchain.blockchain"]["gateway"])

    def test_build_manifest_includes_urls(self) -> None:
        manifest = build_manifest(
            root_cid="bafytest",
            gateway="https://gateway.example/ipfs",
            local_api="http://127.0.0.1:8080",
            build_tag="abc123",
            realms=default_realms("bafytest", "https://gateway.example/ipfs"),
        )
        self.assertEqual(manifest["bridge"], "bifrost-v1")
        self.assertIn("commandCenter", manifest["urls"])

    def test_write_dashboard_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "dashboard").mkdir()
            manifest = build_manifest(
                root_cid="bafytest",
                gateway="https://gateway.example/ipfs",
                local_api="http://127.0.0.1:8080",
                build_tag="test",
                realms={},
            )
            write_dashboard_config(root, manifest)
            text = (root / "dashboard" / "config.js").read_text(encoding="utf-8")
            self.assertIn("YIELDSWARM_CONFIG", text)
            self.assertIn("bifrost", text)


if __name__ == "__main__":
    unittest.main()
