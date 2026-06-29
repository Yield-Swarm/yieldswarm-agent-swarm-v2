"""Application configuration."""

from __future__ import annotations

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_DIR = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))
CONFIG_PATH = Path(
    os.environ.get(
        "CONTROL_CENTER_DEVICES",
        REPO_ROOT / "config" / "control-center" / "devices.yaml",
    )
)

HOST = os.environ.get("CONTROL_CENTER_HOST", "0.0.0.0")
PORT = int(os.environ.get("CONTROL_CENTER_PORT", "8095"))
POLL_INTERVAL_SEC = float(os.environ.get("CONTROL_CENTER_POLL_SEC", "15"))
WS_BROADCAST_SEC = float(os.environ.get("CONTROL_CENTER_WS_SEC", "2"))
PING_TIMEOUT_SEC = float(os.environ.get("CONTROL_CENTER_PING_TIMEOUT", "2"))
HTTP_TIMEOUT_SEC = float(os.environ.get("CONTROL_CENTER_HTTP_TIMEOUT", "4"))
