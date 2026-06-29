#!/usr/bin/env python3
"""Minimal HTTP health server for Akash lease monitoring."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path not in ("/health", "/healthz", "/"):
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(
            {
                "status": "ok",
                "service": os.environ.get("ODYSSEUS_SERVICE_NAME", "yieldswarm-akash"),
                "shard": os.environ.get("AGENT_SHARD_ID", "0"),
            }
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        return


def main() -> None:
    port = int(os.environ.get("HEALTH_PORT", "8080"))
    HTTPServer(("0.0.0.0", port), HealthHandler).serve_forever()


if __name__ == "__main__":
    main()
