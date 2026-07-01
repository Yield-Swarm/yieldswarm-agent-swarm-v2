#!/usr/bin/env python3
"""Helix dashboard — serves live heavenEarth.helix ticks from shared-state."""

from __future__ import annotations

import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

REPO_ROOT = Path(__file__).resolve().parents[1]
SHARED_STATE_PATH = REPO_ROOT / "yield-swarm-core" / "shared-state.json"
DEFAULT_PORT = 8096


def load_shared_state() -> dict[str, Any]:
    if not SHARED_STATE_PATH.is_file():
        return {}
    return json.loads(SHARED_STATE_PATH.read_text(encoding="utf-8"))


def helix_tick_payload() -> dict[str, Any]:
    state = load_shared_state()
    heaven = state.get("heavenEarth") or {}
    return {
        "tick": heaven.get("helix") or {},
        "earth": heaven.get("earth") or {},
        "handoffBus": heaven.get("handoffBus") or {},
        "updatedAt": state.get("updatedAt"),
    }


def helix_status_payload() -> dict[str, Any]:
    state = load_shared_state()
    heaven = state.get("heavenEarth") or {}
    helix = heaven.get("helix") or {}
    earth = heaven.get("earth") or {}
    return {
        "service": "helix-dashboard",
        "fusion": "heaven-earth",
        "helix": helix,
        "earth": earth,
        "handoffBus": heaven.get("handoffBus") or {},
        "live": bool(helix.get("lastTickAt")),
        "updatedAt": state.get("updatedAt"),
    }


class HelixHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: Any) -> None:
        return

    def _send_json(self, payload: dict[str, Any], status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"

        if path in ("/", "/helix"):
            self._send_json(helix_status_payload())
            return
        if path == "/helix/tick":
            self._send_json(helix_tick_payload())
            return
        if path == "/helix/status":
            self._send_json(helix_status_payload())
            return
        if path == "/helix/health":
            payload = helix_status_payload()
            helix = payload.get("helix") or {}
            ok = bool(helix.get("lastTickAt"))
            self._send_json(
                {
                    "ok": ok,
                    "tick": helix.get("tick", 0),
                    "phase": helix.get("phase", "genesis-pending"),
                    "synced": (payload.get("handoffBus") or {}).get("synced", False),
                },
                status=HTTPStatus.OK if ok else HTTPStatus.SERVICE_UNAVAILABLE,
            )
            return

        self._send_json({"error": "not found", "path": path}, status=HTTPStatus.NOT_FOUND)


def main() -> None:
    import os

    port = int(os.environ.get("HELIX_DASHBOARD_PORT", DEFAULT_PORT))
    server = ThreadingHTTPServer(("127.0.0.1", port), HelixHandler)
    print(f"[helix-dashboard] listening on http://127.0.0.1:{port}/helix")
    server.serve_forever()


if __name__ == "__main__":
    main()
