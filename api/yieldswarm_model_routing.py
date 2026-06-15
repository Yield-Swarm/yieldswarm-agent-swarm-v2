"""HTTP API for YieldSwarm Akash model routing.

Run locally:
    python api/yieldswarm_model_routing.py
"""

from __future__ import annotations

import json
import os
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Dict, Tuple
from urllib.parse import parse_qs, urlparse

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from services.yieldswarm_model_router import YieldSwarmModelRouter


ROUTER = YieldSwarmModelRouter.from_env()


def _json_response(handler: BaseHTTPRequestHandler, status: int, payload: object) -> None:
    body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _read_json(handler: BaseHTTPRequestHandler) -> Dict[str, object]:
    content_length = int(handler.headers.get("Content-Length", "0"))
    if content_length <= 0:
        return {}
    raw = handler.rfile.read(content_length).decode("utf-8")
    return json.loads(raw or "{}")


def _query_params(path: str) -> Tuple[str, Dict[str, str]]:
    parsed = urlparse(path)
    query = {
        key: values[-1]
        for key, values in parse_qs(parsed.query, keep_blank_values=True).items()
    }
    return parsed.path, query


class YieldSwarmModelRoutingHandler(BaseHTTPRequestHandler):
    """Small stdlib JSON API for model route operations."""

    server_version = "YieldSwarmModelRouting/1.0"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        path, query = _query_params(self.path)
        try:
            if path == "/health":
                _json_response(self, 200, {"ok": True, "service": "model-routing"})
            elif path == "/api/yieldswarm/models":
                _json_response(self, 200, {"models": ROUTER.model_catalog_snapshot()})
            elif path == "/api/yieldswarm/workers":
                _json_response(self, 200, {"workers": ROUTER.workers_snapshot()})
            elif path == "/api/yieldswarm/models/recommend":
                decision = ROUTER.recommend(
                    task=query.get("task", "chat"),
                    agent_id=query.get("agent_id"),
                    priority=float(query.get("priority", "0.5")),
                    mutation_score=(
                        float(query["mutation_score"])
                        if "mutation_score" in query
                        else None
                    ),
                )
                _json_response(self, 200, {"route": decision.to_dict()})
            elif path == "/api/yieldswarm/models/routes":
                task = query.get("task", "chat")
                _json_response(self, 200, {"task": task, "routes": ROUTER.routes_for_task(task)})
            else:
                _json_response(self, 404, {"error": f"Unknown endpoint: {path}"})
        except Exception as exc:  # pragma: no cover - keeps API errors JSON-shaped
            _json_response(self, 400, {"error": str(exc)})

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        path, _query = _query_params(self.path)
        try:
            payload = _read_json(self)
            if path == "/api/yieldswarm/infer/route":
                decision = ROUTER.route_request(
                    task=str(payload.get("task", "chat")),
                    agent_id=(
                        str(payload["agent_id"]) if payload.get("agent_id") else None
                    ),
                    priority=float(payload.get("priority", 0.5)),
                    mutation_score=(
                        float(payload["mutation_score"])
                        if payload.get("mutation_score") is not None
                        else None
                    ),
                    autoload=bool(payload.get("autoload", True)),
                )
                _json_response(self, 200, {"route": decision.to_dict()})
            elif path == "/api/yieldswarm/infer/complete":
                ROUTER.complete_request(
                    worker_id=str(payload["worker_id"]),
                    model_id=str(payload["model_id"]),
                )
                _json_response(self, 200, {"ok": True})
            elif path == "/api/yieldswarm/models/load":
                decision = ROUTER.load_model(
                    model_id=str(payload["model_id"]),
                    worker_id=(
                        str(payload["worker_id"]) if payload.get("worker_id") else None
                    ),
                )
                _json_response(self, 200, {"route": decision.to_dict()})
            elif path == "/api/yieldswarm/models/unload":
                result = ROUTER.unload_model(
                    model_id=str(payload["model_id"]),
                    worker_id=(
                        str(payload["worker_id"]) if payload.get("worker_id") else None
                    ),
                )
                _json_response(self, 200, result)
            elif path == "/api/yieldswarm/workload/rebalance":
                _json_response(self, 200, ROUTER.rebalance(payload))
            else:
                _json_response(self, 404, {"error": f"Unknown endpoint: {path}"})
        except Exception as exc:  # pragma: no cover - keeps API errors JSON-shaped
            _json_response(self, 400, {"error": str(exc)})

    def log_message(self, format: str, *args: object) -> None:
        if os.getenv("YIELDSWARM_API_ACCESS_LOG", "false").lower() == "true":
            super().log_message(format, *args)


def main() -> None:
    host = os.getenv("YIELDSWARM_ROUTER_HOST", "0.0.0.0")
    port = int(os.getenv("YIELDSWARM_ROUTER_PORT", "8088"))
    server = ThreadingHTTPServer((host, port), YieldSwarmModelRoutingHandler)
    print(f"YieldSwarm model routing API listening on {host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
