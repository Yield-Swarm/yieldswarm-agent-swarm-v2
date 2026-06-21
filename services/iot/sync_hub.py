"""Multi-screen sync hub for Fire TV and Apple TV dashboards."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Dict, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]


class SyncHub:
    """Broadcast dashboard state to registered TV screens."""

    def __init__(self, path: Optional[Path] = None):
        run = Path(__import__("os").environ.get("RUN_DIR", REPO_ROOT / ".run"))
        self.path = path or (run / "iot" / "sync_state.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def publish(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        state = {
            "payload": payload,
            "published_at": time.time(),
            "version": int(time.time()),
        }
        self.path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        return state

    def latest(self) -> Dict[str, Any]:
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return {"payload": {}, "published_at": 0, "version": 0}
