"""Live Arena leaderboard HTTP API."""

from __future__ import annotations

import json
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict
from urllib.parse import parse_qs, urlparse

from agents.system.engine import MutatedChartingEngine


ENGINE: MutatedChartingEngine | None = None


def _json(handler: BaseHTTPRequestHandler, status: int, payload: Dict[str, object]) -> None:
    data = json.dumps(payload, sort_keys=True).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


class ArenaLeaderboardHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    @property
    def engine(self) -> MutatedChartingEngine:
        if ENGINE is None:
            raise RuntimeError("Engine not initialized")
        return ENGINE

    def _parse_body(self) -> Dict[str, object]:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            return {}
        body = self.rfile.read(content_length).decode("utf-8")
        if not body:
            return {}
        return json.loads(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        self.engine.heartbeat_cycle()

        if parsed.path == "/health":
            _json(
                self,
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "timestamp": int(time.time()),
                    "agent_count": len(self.engine.agents),
                },
            )
            return

        if parsed.path == "/arena/leaderboard":
            limit = int(query.get("limit", ["100"])[0])
            _json(
                self,
                HTTPStatus.OK,
                {"leaderboard": self.engine.leaderboard(limit=limit), "limit": limit},
            )
            return

        if parsed.path == "/arena/stats":
            snapshot = self.engine.snapshot(note="live-stats")
            _json(self, HTTPStatus.OK, snapshot)
            return

        if parsed.path.startswith("/arena/agents/"):
            agent_id = parsed.path.rsplit("/", 1)[-1]
            if agent_id not in self.engine.agents:
                _json(self, HTTPStatus.NOT_FOUND, {"error": "agent_not_found"})
                return
            _json(self, HTTPStatus.OK, {"agent": self.engine.get_agent(agent_id)})
            return

        _json(self, HTTPStatus.NOT_FOUND, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        body = self._parse_body()

        if parsed.path == "/arena/heartbeat":
            agent_id = str(body["agent_id"])
            if agent_id not in self.engine.agents:
                _json(self, HTTPStatus.NOT_FOUND, {"error": "agent_not_found"})
                return
            state = self.engine.heartbeat(agent_id).to_public()
            _json(self, HTTPStatus.OK, {"agent": state})
            return

        if parsed.path == "/arena/performance":
            agent_id = str(body["agent_id"])
            if agent_id not in self.engine.agents:
                _json(self, HTTPStatus.NOT_FOUND, {"error": "agent_not_found"})
                return
            state = self.engine.report_performance(
                agent_id=agent_id,
                arena_score=float(body.get("arena_score", 0)),
                signal_precision=float(body.get("signal_precision", 0.5)),
                pnl_bps=float(body.get("pnl_bps", 0)),
            )
            _json(self, HTTPStatus.OK, {"agent": state})
            return

        if parsed.path == "/arena/mutate":
            ratio = float(body.get("ratio", 0.1))
            batch_size = int(body.get("batch_size", 256))
            result = self.engine.mutate_bottom_performers(ratio=ratio, batch_size=batch_size)
            _json(self, HTTPStatus.OK, result)
            return

        if parsed.path == "/arena/archive":
            note = str(body.get("note", "manual-archive"))
            entry = self.engine.archive_snapshot(note=note)
            _json(self, HTTPStatus.OK, {"archive": entry})
            return

        _json(self, HTTPStatus.NOT_FOUND, {"error": "not_found"})

    def log_message(self, format: str, *args: object) -> None:  # noqa: A003
        # Intentionally quiet in cloud runs.
        return


def run_server(host: str = "0.0.0.0", port: int = 8420, root_dir: Path | str = "/workspace/agents") -> None:
    global ENGINE
    ENGINE = MutatedChartingEngine(root_dir=root_dir)
    server = ThreadingHTTPServer((host, port), ArenaLeaderboardHandler)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    run_server()
