#!/usr/bin/env python3
"""YieldSwarm worker node.

A lightweight HTTP service that runs on each Akash lease / cloud-fallback
instance. The frontend dashboard is wired to one or more of these worker URLs
(see deploy/scripts/update-frontend-urls.sh).

Endpoints
---------
GET /            -> JSON node identity + status
GET /healthz     -> 200 "ok" liveness probe (used by Akash auto-heal + Terraform)
GET /readyz      -> 200 when the shard has finished warming up
GET /metrics     -> Prometheus exposition (scraped by the monitoring stack)
GET /api/status  -> swarm status payload consumed by the dashboard

Runs on the Python standard library only so the container is tiny and boots
fast. Configuration is via environment variables (see .env.example).
"""
from __future__ import annotations

import json
import os
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

START_TIME = time.time()
READY = threading.Event()

SHARD_ID = os.environ.get("AGENT_SHARD_ID", "0")
SHARD_COUNT = int(os.environ.get("CRON_SHARD_COUNT", "120"))
AGENTS_PER_SHARD = int(os.environ.get("AGENTS_PER_SHARD", "84"))
TOTAL_AGENTS = int(os.environ.get("AGENT_COUNT_TOTAL", "10080"))
NODE_NAME = os.environ.get("NODE_NAME", socket.gethostname())
PORT = int(os.environ.get("WORKER_PORT", os.environ.get("PORT", "8080")))
VERSION = os.environ.get("IMAGE_TAG", "dev")

# Lightweight in-process counters (also exported to Prometheus).
_requests_total = 0
_lock = threading.Lock()


def _identity() -> dict:
    return {
        "service": "yieldswarm-worker",
        "node": NODE_NAME,
        "version": VERSION,
        "shard_id": SHARD_ID,
        "shard_count": SHARD_COUNT,
        "agents_on_node": AGENTS_PER_SHARD,
        "agents_total": TOTAL_AGENTS,
        "uptime_seconds": round(time.time() - START_TIME, 1),
        "ready": READY.is_set(),
    }


def _metrics() -> str:
    uptime = time.time() - START_TIME
    with _lock:
        reqs = _requests_total
    lines = [
        "# HELP yieldswarm_worker_up Worker liveness (1 = up).",
        "# TYPE yieldswarm_worker_up gauge",
        f'yieldswarm_worker_up{{node="{NODE_NAME}",shard="{SHARD_ID}"}} 1',
        "# HELP yieldswarm_worker_uptime_seconds Seconds since worker start.",
        "# TYPE yieldswarm_worker_uptime_seconds gauge",
        f'yieldswarm_worker_uptime_seconds{{node="{NODE_NAME}"}} {uptime:.1f}',
        "# HELP yieldswarm_worker_agents Agents served by this node.",
        "# TYPE yieldswarm_worker_agents gauge",
        f'yieldswarm_worker_agents{{node="{NODE_NAME}",shard="{SHARD_ID}"}} {AGENTS_PER_SHARD}',
        "# HELP yieldswarm_worker_requests_total HTTP requests handled.",
        "# TYPE yieldswarm_worker_requests_total counter",
        f'yieldswarm_worker_requests_total{{node="{NODE_NAME}"}} {reqs}',
        "# HELP yieldswarm_worker_ready Readiness (1 = ready).",
        "# TYPE yieldswarm_worker_ready gauge",
        f'yieldswarm_worker_ready{{node="{NODE_NAME}"}} {1 if READY.is_set() else 0}',
    ]
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    server_version = "yieldswarm-worker/1.0"

    def _send(self, code: int, body: str, content_type: str = "application/json") -> None:
        payload = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802 (stdlib naming)
        global _requests_total
        with _lock:
            _requests_total += 1
        path = self.path.split("?", 1)[0].rstrip("/") or "/"

        if path == "/":
            self._send(200, json.dumps(_identity(), indent=2))
        elif path == "/healthz":
            self._send(200, "ok", "text/plain")
        elif path == "/readyz":
            if READY.is_set():
                self._send(200, "ready", "text/plain")
            else:
                self._send(503, "warming-up", "text/plain")
        elif path == "/metrics":
            self._send(200, _metrics(), "text/plain; version=0.0.4")
        elif path == "/api/status":
            self._send(200, json.dumps({
                "status": "live",
                "consensus": "kimiclaw",
                "council_threshold": "9/14",
                **_identity(),
            }))
        else:
            self._send(404, json.dumps({"error": "not found", "path": path}))

    def log_message(self, fmt: str, *args) -> None:
        # Route access logs to stdout in a structured, compact form.
        print(f"[worker] {self.address_string()} {fmt % args}", flush=True)


def _warmup() -> None:
    # Simulate shard warm-up (cert load, peer discovery, council handshake).
    time.sleep(float(os.environ.get("WORKER_WARMUP_SECONDS", "2")))
    READY.set()
    print(f"[worker] shard {SHARD_ID} ready ({AGENTS_PER_SHARD} agents)", flush=True)


def main() -> None:
    threading.Thread(target=_warmup, daemon=True).start()
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(
        f"[worker] yieldswarm-worker {VERSION} listening on :{PORT} "
        f"(node={NODE_NAME}, shard={SHARD_ID}/{SHARD_COUNT})",
        flush=True,
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("[worker] shutting down", flush=True)
        httpd.shutdown()


if __name__ == "__main__":
    main()
