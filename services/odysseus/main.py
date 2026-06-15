"""Minimal Odysseus service process used by deployment artifacts."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


REQUIRED_SECRET_KEYS = (
    "ODYSSEUS_API_KEY",
    "ODYSSEUS_MODEL_HOST",
    "ODYSSEUS_MODEL_API_KEY",
)


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def _status_payload() -> dict[str, Any]:
    missing = [key for key in REQUIRED_SECRET_KEYS if not os.getenv(key)]
    return {
        "service": os.getenv("ODYSSEUS_SERVICE_NAME", "odysseus"),
        "status": "ready" if not missing else "degraded",
        "agent_count": _env_int("ODYSSEUS_AGENT_COUNT", 84),
        "shard_id": _env_int("AGENT_SHARD_ID", 0),
        "gpu_count": _env_int("ODYSSEUS_GPU_COUNT", 1),
        "vault_path": os.getenv("ODYSSEUS_RUNTIME_VAULT_PATH") or os.getenv("VAULT_KV_PATH"),
        "missing_secret_keys": missing,
    }


class HealthHandler(BaseHTTPRequestHandler):
    server_version = "OdysseusHealth/1.0"

    def do_GET(self) -> None:  # noqa: N802 - http.server uses this method name.
        if self.path not in {"/", "/healthz", "/readyz"}:
            self.send_error(404)
            return

        payload = _status_payload()
        status = 200 if payload["status"] == "ready" else 503
        body = json.dumps(payload, sort_keys=True).encode("utf-8")

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: Any) -> None:
        if os.getenv("LOG_LEVEL", "INFO").upper() != "ERROR":
            super().log_message(fmt, *args)


def main() -> None:
    host = os.getenv("HOST", "0.0.0.0")
    port = _env_int("PORT", 8080)
    server = ThreadingHTTPServer((host, port), HealthHandler)
    print(f"Odysseus service listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
