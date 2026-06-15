"""Odysseus orchestration service for YieldSwarm production."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

REQUIRED_SECRET_KEYS = (
    "ODYSSEUS_API_KEY",
    "ODYSSEUS_MODEL_HOST",
    "ODYSSEUS_MODEL_API_KEY",
)

AGENT_COUNT_TOTAL = 10_080
DEITY_COUNT = 169
CRON_SHARD_COUNT = 120


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def _http_json(method: str, url: str, body: dict[str, Any] | None = None, headers: dict[str, str] | None = None) -> dict[str, Any]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        return {"error": exc.read().decode(), "status": exc.code}
    except Exception as exc:
        return {"error": str(exc)}


def _chromadb_heartbeat() -> dict[str, Any]:
    base = os.getenv("CHROMADB_URL", "http://chromadb:8000")
    return _http_json("GET", f"{base.rstrip('/')}/api/v1/heartbeat")


def _litellm_models() -> dict[str, Any]:
    base = os.getenv("LITELLM_URL", "http://llm-router:4000")
    key = os.getenv("YIELDSWARM_ROUTER_API_KEY", os.getenv("LITELLM_MASTER_KEY", ""))
    headers = {"Authorization": f"Bearer {key}"} if key else {}
    return _http_json("GET", f"{base.rstrip('/')}/v1/models", headers=headers)


def _ollama_tags() -> dict[str, Any]:
    base = os.getenv("AKASH_OLLAMA_BASE_URL", os.getenv("LOCAL_OLLAMA_BASE_URL", "http://ollama:11434"))
    return _http_json("GET", f"{base.rstrip('/')}/api/tags")


def _status_payload() -> dict[str, Any]:
    missing = [key for key in REQUIRED_SECRET_KEYS if not os.getenv(key)]
    chroma = _chromadb_heartbeat()
    models = _litellm_models()
    ollama = _ollama_tags()

    providers = {
        "openrouter": bool(os.getenv("OPENROUTER_API_KEY")),
        "fireworks": bool(os.getenv("FIREWORKS_API_KEY")),
        "akash_ollama": "models" in ollama or "error" not in ollama,
    }

    return {
        "service": os.getenv("ODYSSEUS_SERVICE_NAME", "odysseus"),
        "status": "ready" if not missing else "degraded",
        "agent_count": _env_int("ODYSSEUS_AGENT_COUNT", 84),
        "agent_count_total": AGENT_COUNT_TOTAL,
        "deity_count": DEITY_COUNT,
        "cron_shard_count": CRON_SHARD_COUNT,
        "shard_id": _env_int("AGENT_SHARD_ID", 0),
        "gpu_count": _env_int("ODYSSEUS_GPU_COUNT", 1),
        "vault_path": os.getenv("ODYSSEUS_RUNTIME_VAULT_PATH") or os.getenv("VAULT_KV_PATH"),
        "missing_secret_keys": missing,
        "memory": {"chromadb": chroma},
        "router": {"litellm": models, "providers": providers},
        "akash_ollama": ollama,
    }


def _orchestrate(body: dict[str, Any]) -> dict[str, Any]:
    """Proxy a chat completion to LiteLLM with YieldSwarm model aliases."""
    base = os.getenv("LITELLM_URL", "http://llm-router:4000")
    key = os.getenv("YIELDSWARM_ROUTER_API_KEY", os.getenv("LITELLM_MASTER_KEY", ""))
    model = body.get("model", "yieldswarm-default")
    payload = {
        "model": model,
        "messages": body.get("messages", []),
        "max_tokens": body.get("max_tokens", 1024),
    }
    headers = {"Authorization": f"Bearer {key}"} if key else {}
    return _http_json("POST", f"{base.rstrip('/')}/v1/chat/completions", payload, headers)


def _swarm_status() -> dict[str, Any]:
    shard = _env_int("AGENT_SHARD_ID", 0)
    agents_per_shard = AGENT_COUNT_TOTAL // CRON_SHARD_COUNT
    return {
        "total_agents": AGENT_COUNT_TOTAL,
        "mutated_agents": AGENT_COUNT_TOTAL,
        "deities": DEITY_COUNT,
        "cron_shards": CRON_SHARD_COUNT,
        "current_shard": shard,
        "agents_in_shard": agents_per_shard,
        "agent_range": [shard * agents_per_shard, (shard + 1) * agents_per_shard - 1],
        "memory_backend": os.getenv("CHROMADB_URL", "http://chromadb:8000"),
        "model_aliases": [
            "yieldswarm-default",
            "yieldswarm-fireworks",
            "akash-ollama",
            "akash-ollama-embed",
            "local-ollama",
        ],
    }


class OdysseusHandler(BaseHTTPRequestHandler):
    server_version = "OdysseusOrchestrator/2.0"

    def _send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        body = json.dumps(payload, sort_keys=True).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode() or "{}")

    def _check_auth(self) -> bool:
        expected = os.getenv("ODYSSEUS_API_KEY", "")
        if not expected:
            return True
        auth = self.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ").strip()
        return token == expected

    def do_GET(self) -> None:  # noqa: N802
        if self.path in {"/", "/healthz", "/readyz"}:
            payload = _status_payload()
            status = 200 if payload["status"] == "ready" else 503
            self._send_json(payload, status)
            return
        if self.path == "/api/swarm/status":
            self._send_json(_swarm_status())
            return
        if self.path == "/api/memory/heartbeat":
            self._send_json(_chromadb_heartbeat())
            return
        self.send_error(404)

    def do_POST(self) -> None:  # noqa: N802
        if not self._check_auth():
            self._send_json({"error": "unauthorized"}, 401)
            return
        if self.path == "/api/orchestrate":
            body = self._read_json()
            self._send_json(_orchestrate(body))
            return
        self.send_error(404)

    def log_message(self, fmt: str, *args: Any) -> None:
        if os.getenv("LOG_LEVEL", "INFO").upper() != "ERROR":
            super().log_message(fmt, *args)


def main() -> None:
    host = os.getenv("HOST", "0.0.0.0")
    port = _env_int("PORT", 8080)
    server = ThreadingHTTPServer((host, port), OdysseusHandler)
    print(f"Odysseus orchestrator listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
