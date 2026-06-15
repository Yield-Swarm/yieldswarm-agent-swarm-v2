"""Odysseus orchestration service — agents, memory, LLM proxy status."""

from __future__ import annotations

import json
import os
import urllib.request
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


def _ping(url: str, timeout: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return resp.status < 500
    except Exception:
        return False


def _status_payload() -> dict[str, Any]:
    missing = [key for key in REQUIRED_SECRET_KEYS if not os.getenv(key)]
    llm_host = os.getenv("ODYSSEUS_MODEL_HOST", os.getenv("LLM_HOST", "http://llm-router:4000"))
    chroma_url = os.getenv("CHROMADB_URL", "http://chromadb:8000")
    return {
        "service": os.getenv("ODYSSEUS_SERVICE_NAME", "odysseus"),
        "status": "ready" if not missing else "degraded",
        "agent_count": _env_int("ODYSSEUS_AGENT_COUNT", 84),
        "total_agents": _env_int("AGENT_COUNT_TOTAL", 10080),
        "deity_count": 169,
        "shard_id": _env_int("AGENT_SHARD_ID", 0),
        "gpu_count": _env_int("ODYSSEUS_GPU_COUNT", 1),
        "vault_path": os.getenv("ODYSSEUS_RUNTIME_VAULT_PATH") or os.getenv("VAULT_KV_PATH"),
        "missing_secret_keys": missing,
        "upstreams": {
            "llm_router": {"url": llm_host, "live": _ping(f"{llm_host.rstrip('/')}/health")},
            "chromadb": {"url": chroma_url, "live": _ping(f"{chroma_url.rstrip('/')}/api/v1/heartbeat")},
        },
        "tools": ["akash_lease", "treasury_rebalance", "agent_mutate", "chromadb_sync"],
    }


class OdysseusHandler(BaseHTTPRequestHandler):
    server_version = "OdysseusOrchestrator/1.1"

    def do_GET(self) -> None:  # noqa: N802
        routes = {
            "/": _status_payload,
            "/healthz": _status_payload,
            "/readyz": _status_payload,
            "/api/agents": lambda: {"agents": _env_int("ODYSSEUS_AGENT_COUNT", 84), "shard": _env_int("AGENT_SHARD_ID", 0)},
            "/api/memory": lambda: {"backend": "chromadb", "url": os.getenv("CHROMADB_URL", "http://chromadb:8000")},
        }
        handler = routes.get(self.path)
        if not handler:
            self.send_error(404)
            return
        payload = handler()
        status = 200 if payload.get("status") != "degraded" else 503
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
    port = _env_int("ODYSSEUS_PORT", 8080)
    server = ThreadingHTTPServer(("0.0.0.0", port), OdysseusHandler)
    print(f"Odysseus orchestrator listening on :{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
