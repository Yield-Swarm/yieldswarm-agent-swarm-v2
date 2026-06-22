"""Elevator node entrypoint: python3 -m yieldswarm.core --root <key> --node-id <n> --auth <key>."""

from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from yieldswarm.auth import resolve_primary_key, validate_key
from yieldswarm.book_roots import BookRoot, get_root


def _mount_state(root: BookRoot) -> dict:
    root.state_dir.mkdir(parents=True, exist_ok=True)
    state_file = root.state_dir / "state.json"
    if state_file.is_file():
        state = json.loads(state_file.read_text(encoding="utf-8"))
    else:
        state = {
            "root": root.key,
            "pillar": root.pillar,
            "pillar_name": root.pillar_name,
            "mounted_at": datetime.now(timezone.utc).isoformat(),
            "status": "initialized",
        }
        state_file.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return state


def _heartbeat(root: BookRoot, node_id: int) -> dict:
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "root": root.key,
        "node_id": node_id,
        "pillar": root.pillar,
        "pillar_name": root.pillar_name,
        "state_dir": str(root.state_dir),
        "ok": True,
    }


def run(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm book-root elevator node")
    parser.add_argument("--root", required=True, help="Book root key (e.g. root_01_genesis)")
    parser.add_argument("--node-id", type=int, required=True, help="Elevator node id 1..14")
    parser.add_argument("--auth", help="Swarm API key (defaults to SWARM_API_KEY_PRIMARY)")
    parser.add_argument("--interval", type=float, default=30.0, help="Heartbeat interval seconds")
    parser.add_argument("--once", action="store_true", help="Single heartbeat then exit")
    args = parser.parse_args(argv)

    expected = resolve_primary_key(args.auth)
    if args.auth:
        validate_key(args.auth, expected)

    root = get_root(args.root)
    if root.id != args.node_id:
        print(
            f"warning: node-id {args.node_id} does not match registry id {root.id} for {root.key}",
            file=sys.stderr,
        )

    state = _mount_state(root)
    pid_file = root.state_dir / "elevator.pid"
    pid_file.write_text(str(os.getpid()), encoding="utf-8")

    print(json.dumps({"event": "elevator_start", "state": state, "node_id": args.node_id}))

    stop = False

    def _handle_sigterm(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, _handle_sigterm)
    signal.signal(signal.SIGINT, _handle_sigterm)

    while not stop:
        pulse = _heartbeat(root, args.node_id)
        print(json.dumps({"event": "heartbeat", **pulse}), flush=True)
        if args.once:
            break
        time.sleep(max(1.0, args.interval))

    print(json.dumps({"event": "elevator_stop", "root": root.key}))
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
