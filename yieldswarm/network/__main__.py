"""Swarm network entrypoint: python3 -m yieldswarm.network --swarm-mode elisazos --key <key>."""

from __future__ import annotations

import argparse
import json
import signal
import sys
import time
from datetime import datetime, timezone

from services.neural_mesh.elevators import NeuralMeshElevators
from yieldswarm.auth import resolve_backend_key, resolve_primary_key
from yieldswarm.book_roots import load_book_roots


def _sync_matrix(primary_key: str, backend_key: str | None) -> dict:
    roots = load_book_roots()
    mesh = NeuralMeshElevators()
    payloads = [
        {
            "root": r.key,
            "node_id": r.id,
            "pillar": r.pillar,
            "pillar_name": r.pillar_name,
            "auth_scope": "primary",
        }
        for r in roots
    ]

    def handler(i: int, payload: dict) -> dict:
        root = roots[i]
        mounted = root.state_dir.is_dir()
        return {
            **payload,
            "mounted": mounted,
            "lane": i + 1,
        }

    lanes = mesh.run_matrix(payloads, handler)
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "mode": "elisazos",
        "lanes": lanes,
        "mesh": mesh.status(),
        "backend_bound": backend_key is not None,
        "primary_fingerprint": primary_key[:6] + "******",
    }


def run(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm Elisazos swarm network layer")
    parser.add_argument("--swarm-mode", default="elisazos", choices=["elisazos"])
    parser.add_argument("--key", help="Primary swarm API key")
    parser.add_argument("--backend-key", help="Secondary backend API key")
    parser.add_argument("--interval", type=float, default=60.0, help="Sync interval seconds")
    parser.add_argument("--once", action="store_true", help="Single sync then exit")
    args = parser.parse_args(argv)

    primary = resolve_primary_key(args.key)
    backend = resolve_backend_key(args.backend_key)

    print(
        json.dumps(
            {
                "event": "swarm_start",
                "mode": args.swarm_mode,
                "primary_fingerprint": primary[:6] + "******",
                "backend_bound": backend is not None,
            }
        ),
        flush=True,
    )

    stop = False

    def _handle_sigterm(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, _handle_sigterm)
    signal.signal(signal.SIGINT, _handle_sigterm)

    while not stop:
        snapshot = _sync_matrix(primary, backend)
        print(json.dumps({"event": "swarm_sync", **snapshot}), flush=True)
        if args.once:
            break
        time.sleep(max(5.0, args.interval))

    print(json.dumps({"event": "swarm_stop", "mode": args.swarm_mode}))
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
