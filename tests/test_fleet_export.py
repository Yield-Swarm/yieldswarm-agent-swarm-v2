"""Tests for fleet export from .env.fleet matrix."""

import json
import subprocess
import sys
from pathlib import Path


def test_fleet_export_grass_node(tmp_path):
    fleet = tmp_path / ".env.fleet"
    fleet.write_text(
        """
NODE_0_ROLE=grass
NODE_0_MODEL=Pixel_10a
NODE_0_SERIAL=352986470733266
NODE_0_MAC=30:e0:44:8e:9d:49
NODE_0_PLATFORM=android
FLEET_DEFAULT_WALLET=0xabc
""".strip()
    )
    repo = Path(__file__).resolve().parents[1]
    script = repo / "scripts" / "fleet" / "fleet_export.py"
    out = subprocess.check_output(
        [sys.executable, str(script), "--node", "0", "--fleet", str(fleet), "--json"],
        text=True,
    )
    data = json.loads(out)
    assert data["role"] == "grass"
    assert len(data["GRASS_NODE_KEYS"]) == 1
    assert data["GRASS_NODE_KEYS"][0]["platform"] == "android"


def test_fleet_export_helium_node(tmp_path):
    fleet = tmp_path / ".env.fleet"
    fleet.write_text(
        """
NODE_4_ROLE=helium
NODE_4_MODEL=HNT-ODU-0012
NODE_4_SERIAL=60013006881
NODE_4_MAC=60:6d:3c:5f:14:1c
NODE_4_SSID=Helium-5G-141C
""".strip()
    )
    repo = Path(__file__).resolve().parents[1]
    script = repo / "scripts" / "fleet" / "fleet_export.py"
    out = subprocess.check_output(
        [sys.executable, str(script), "--node", "4", "--fleet", str(fleet), "--json"],
        text=True,
    )
    data = json.loads(out)
    assert data["role"] == "helium"
    assert data["DEPIN_HELIUM_HOTSPOT_KEYS"][0]["serial"] == "60013006881"
