#!/usr/bin/env python3
"""AgentSwarm fallback worker entrypoint.

A minimal, dependency-free supervisor that brings a worker online when Akash is
saturated and the multi-cloud fallback fleet is scaled up. It:

  * derives its identity from the environment injected by Terraform / cloud-init,
  * registers with the control plane (best-effort) on startup,
  * runs `AGENTS_PER_SHARD` agent slots,
  * emits a heartbeat the container HEALTHCHECK watches.

Replace `run_agent_shard` with the real AgentSwarm agent runtime.
"""
import json
import os
import signal
import socket
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

HEARTBEAT_FILE = "/tmp/agentswarm-worker.heartbeat"

_running = True


def _log(msg: str) -> None:
    ts = datetime.now(timezone.utc).isoformat()
    print(f"[{ts}] {msg}", flush=True)


def _stop(signum, _frame) -> None:
    global _running
    _log(f"received signal {signum}; draining worker")
    _running = False


def register(endpoint: str, identity: dict) -> None:
    if not endpoint:
        _log("no CONTROL_PLANE_ENDPOINT set; running standalone")
        return
    try:
        data = json.dumps(identity).encode("utf-8")
        req = urllib.request.Request(
            endpoint.rstrip("/") + "/workers/register",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            _log(f"registered with control plane: HTTP {resp.status}")
    except (urllib.error.URLError, OSError) as exc:
        _log(f"control plane registration failed (will keep running): {exc}")


def run_agent_shard(shard_index: int, identity: dict) -> None:
    """Placeholder for one agent slot's unit of work."""
    _ = (shard_index, identity)


def main() -> int:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    identity = {
        "provider": os.environ.get("WORKER_PROVIDER", "unknown"),
        "instance_id": os.environ.get("WORKER_INSTANCE_ID", socket.gethostname()),
        "environment": os.environ.get("AGENTSWARM_ENV", "unknown"),
        "agents_per_shard": int(os.environ.get("AGENTS_PER_SHARD", "84")),
        "fallback_mode": os.environ.get("WORKER_FALLBACK_MODE", "true"),
    }
    _log(f"starting worker {identity}")

    register(os.environ.get("CONTROL_PLANE_ENDPOINT", ""), identity)

    loop_seconds = int(os.environ.get("WORKER_LOOP_SECONDS", "15"))
    while _running:
        for shard_index in range(identity["agents_per_shard"]):
            run_agent_shard(shard_index, identity)
        try:
            with open(HEARTBEAT_FILE, "w", encoding="utf-8") as fh:
                fh.write(datetime.now(timezone.utc).isoformat())
        except OSError as exc:
            _log(f"failed to write heartbeat: {exc}")
        time.sleep(loop_seconds)

    _log("worker stopped cleanly")
    return 0


if __name__ == "__main__":
    sys.exit(main())
