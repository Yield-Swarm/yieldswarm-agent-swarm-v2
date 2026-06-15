#!/usr/bin/env python3
"""Smoke integration tests across Kairo, Odysseus memory, and model router."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def test_kairo_ping():
    out = subprocess.check_output([sys.executable, str(ROOT / "kairo/cli.py"), "ping"], text=True)
    data = json.loads(out)
    assert data.get("ok") is True


def test_odysseus_memory_import():
    from agents.odysseus_memory import OdysseusMemory  # noqa: F401


def test_model_router_import():
    from services.yieldswarm_model_router import YieldSwarmModelRouter  # noqa: F401


if __name__ == "__main__":
    test_kairo_ping()
    test_odysseus_memory_import()
    test_model_router_import()
    print("smoke integration: OK")
