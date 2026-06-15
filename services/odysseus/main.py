"""Odysseus brain HTTP API — central orchestration on Akash RTX 3090 workers."""

from __future__ import annotations

import json
import os
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from services.odysseus.brain import OdysseusBrain

SYNC_INTERVAL = int(os.getenv("ODYSSEUS_ROUTER_SYNC_SECONDS", "300"))


class BrainHandler(BaseHTTPRequestHandler):
    brain = OdysseusBrain()

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        try:
            if path in {"/", "/healthz", "/readyz", "/health"}:
                payload = self.brain.health()
                code = HTTPStatus.OK if payload.get("status") == "ready" else HTTPStatus.SERVICE_UNAVAILABLE
                return self._send(code, payload)
            if path == "/api/brain/status":
                return self._send(HTTPStatus.OK, self.brain.health())
            if path == "/api/telemetry/odysseus":
                return self._send(HTTPStatus.OK, self.brain.telemetry())
            if path == "/api/models/routes":
                return self._send(HTTPStatus.OK, self.brain.sync_model_routing())
            if path == "/api/models/recommend":
                qs = parse_qs(parsed.query)
                task = (qs.get("task") or ["chat"])[0]
                agent_id = (qs.get("agent_id") or [None])[0]
                priority = float((qs.get("priority") or ["0.5"])[0])
                return self._send(
                    HTTPStatus.OK,
                    self.brain.route_inference(task=task, agent_id=agent_id, priority=priority),
                )
            if path == "/api/tools":
                return self._send(
                    HTTPStatus.OK,
                    {"tools": self.brain.status.registered_tools},
                )
            if path == "/api/integrations/health":
                return self._send(HTTPStatus.OK, self.brain.integrations_health())
            if path == "/api/governance/consensus/status":
                return self._send(HTTPStatus.OK, self.brain.governance_status())
            if path == "/api/memory/recall":
                qs = parse_qs(parsed.query)
                query = (qs.get("q") or [""])[0]
                limit = int((qs.get("limit") or ["5"])[0])
                types = (qs.get("types") or [None])[0]
                memory_types = types.split(",") if types else None
                rows = self.brain.recall_memory(query, limit=limit, memory_types=memory_types)
                return self._send(HTTPStatus.OK, {"query": query, "results": rows})
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except Exception as exc:  # noqa: BLE001
            self._send(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        try:
            body = self._read_json()
            if path == "/api/tools/execute":
                name = body["name"]
                result = self.brain.execute_tool(name, body.get("arguments"))
                return self._send(HTTPStatus.OK, {"tool": name, "result": result})
            if path == "/api/models/sync":
                routing = self.brain.sync_model_routing()
                return self._send(HTTPStatus.OK, routing)
            if path == "/api/infer/route":
                result = self.brain.route_inference(
                    task=str(body.get("task", "chat")),
                    agent_id=str(body["agent_id"]) if body.get("agent_id") else None,
                    priority=float(body.get("priority", 0.5)),
                )
                return self._send(HTTPStatus.OK, result)
            if path == "/api/governance/consensus/run":
                proposal = body.get("proposal")
                model_count = int(body.get("model_count", 100))
                report = self.brain.run_governance_consensus(
                    proposal=str(proposal) if proposal else None,
                    model_count=model_count,
                )
                return self._send(HTTPStatus.OK, report)
            if path == "/odysseus/memory/sync":
                reports = self.brain.memory.sync_with_peers()
                return self._send(HTTPStatus.OK, {"reports": reports})
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except KeyError as exc:
            self._send(HTTPStatus.BAD_REQUEST, {"error": f"missing field: {exc}"})
        except Exception as exc:  # noqa: BLE001
            self._send(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

    def log_message(self, fmt: str, *args: Any) -> None:
        if os.getenv("LOG_LEVEL", "INFO").upper() != "ERROR":
            super().log_message(fmt, *args)


def _router_sync_loop(brain: OdysseusBrain) -> None:
    while True:
        time.sleep(SYNC_INTERVAL)
        try:
            brain.sync_model_routing()
        except Exception as exc:  # noqa: BLE001
            print(f"[odysseus-brain] router sync failed: {exc}", flush=True)


def main() -> None:
    brain = BrainHandler.brain
    brain.bootstrap()

    if os.getenv("ODYSSEUS_ROUTER_SYNC_ENABLED", "true").lower() in {"1", "true", "yes"}:
        thread = threading.Thread(target=_router_sync_loop, args=(brain,), daemon=True)
        thread.start()

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer((host, port), BrainHandler)
    print(
        f"Odysseus brain listening on http://{host}:{port} "
        f"(agents={brain.status.agent_count}, tools={len(brain.status.registered_tools)})",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
