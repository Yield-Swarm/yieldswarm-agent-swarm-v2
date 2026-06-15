#!/usr/bin/env python3
"""Minimal HTTP health endpoint for Akash lease monitoring."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path not in ("/health", "/healthz", "/"):
            self.send_response(404)
            self.end_headers()
            return

        payload = {
            "status": "ok",
            "service": "yieldswarm-agentswarm",
            "shard": os.environ.get("AGENT_SHARD_ID", "0"),
            "vault_injected": bool(os.environ.get("AGENTSWARM_MASTER_KEY")),
        }
        body = json.dumps(payload).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args: object) -> None:
        return


def main() -> None:
    port = int(os.environ.get("HEALTH_PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    print(f"health server listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
