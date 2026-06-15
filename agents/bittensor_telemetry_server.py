#!/usr/bin/env python3
"""Dual-purpose telemetry server for Akash Bittensor workers (port 8080).

Feeds the Vercel Arena dashboard with Ollama, Bittensor, and GPU metrics.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

STATUS_FILE = Path(os.environ.get("BITTENSOR_STATUS_FILE", "/run/bittensor/status.json"))
STARTED_AT = time.time()
INFERENCE_COUNT = 0
INFERENCE_LATENCY_MS: list[float] = []


def _run(cmd: list[str], timeout: int = 10) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=timeout, text=True)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def ollama_models() -> list[dict[str, Any]]:
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as resp:
            data = json.loads(resp.read())
            return data.get("models", [])
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError):
        return []


def gpu_stats() -> dict[str, Any]:
    raw = _run(
        [
            "nvidia-smi",
            "--query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
        ]
    )
    if not raw.strip():
        return {"available": False}
    parts = [p.strip() for p in raw.strip().split("\n")[0].split(",")]
    if len(parts) < 5:
        return {"available": False}
    return {
        "available": True,
        "name": parts[0],
        "vram_used_mb": int(parts[1]),
        "vram_total_mb": int(parts[2]),
        "utilization_pct": int(parts[3]),
        "temperature_c": int(parts[4]),
    }


def bittensor_status() -> dict[str, Any]:
    if STATUS_FILE.exists():
        try:
            return json.loads(STATUS_FILE.read_text())
        except json.JSONDecodeError:
            pass
    return {
        "running": False,
        "netuid": os.environ.get("BT_NETUID"),
        "network": os.environ.get("BT_NETWORK", "finney"),
        "axon_port": int(os.environ.get("BT_AXON_PORT", "8091")),
        "hotkey": None,
        "last_challenge_at": None,
        "last_challenge_ms": None,
    }


def build_metrics() -> dict[str, Any]:
    global INFERENCE_COUNT
    latencies = INFERENCE_LATENCY_MS[-100:]
    return {
        "service": "yieldswarm-bittensor-telemetry",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_sec": round(time.time() - STARTED_AT, 1),
        "ollama": {
            "reachable": bool(ollama_models()),
            "models": [m.get("name") for m in ollama_models()],
        },
        "bittensor": bittensor_status(),
        "gpu": gpu_stats(),
        "inference": {
            "request_count": INFERENCE_COUNT,
            "avg_latency_ms": round(sum(latencies) / len(latencies), 2) if latencies else 0,
            "p95_latency_ms": round(sorted(latencies)[int(len(latencies) * 0.95) - 1], 2)
            if len(latencies) >= 2
            else (latencies[0] if latencies else 0),
        },
        "akash": {
            "worker_type": "bittensor-dual-purpose",
            "dseq": os.environ.get("AKASH_DSEQ"),
            "provider": os.environ.get("AKASH_PROVIDER"),
        },
    }


class TelemetryHandler(BaseHTTPRequestHandler):
    def _json(self, code: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path in ("/health", "/healthz"):
            self._json(200, {"status": "ok"})
        elif self.path in ("/", "/metrics", "/api/telemetry"):
            self._json(200, build_metrics())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_args: object) -> None:
        return


def record_inference(latency_ms: float) -> None:
    global INFERENCE_COUNT
    INFERENCE_COUNT += 1
    INFERENCE_LATENCY_MS.append(latency_ms)
    if len(INFERENCE_LATENCY_MS) > 1000:
        del INFERENCE_LATENCY_MS[:500]


def main() -> None:
    port = int(os.environ.get("TELEMETRY_PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), TelemetryHandler)
    print(f"telemetry server listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
