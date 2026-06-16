#!/usr/bin/env python3
"""YieldSwarm sovereign loop / agent orchestrator.

This is the long-running "sovereign loop" entrypoint for the agents container.
On each tick it:

  1. Runs every agent module under ./agents (Akash optimizer, OpenClaw scaler,
     Chainlink vault manager, ...).
  2. Runs the mining equipment connector.
  3. Emits a heartbeat + Prometheus-friendly metrics to ./.run and stdout.

It is intentionally resilient: a failing agent is logged and skipped so the
swarm keeps running (sovereign = no single point of failure). The cadence is
controlled by SOVEREIGN_LOOP_INTERVAL (seconds).
"""
from __future__ import annotations

import importlib.util
import os
import sys
import time
import traceback
from pathlib import Path

REPO_ROOT = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[2]))
INTERVAL = int(os.environ.get("SOVEREIGN_LOOP_INTERVAL", "900"))
RUN_DIR = REPO_ROOT / os.environ.get("RUN_DIR", ".run")
ONESHOT = os.environ.get("SOVEREIGN_ONESHOT", "").lower() in ("1", "true", "yes")

AGENT_FILES = [
    REPO_ROOT / "agents" / "akash-optimizer.py",
    REPO_ROOT / "agents" / "openclaw-scaler.py",
    REPO_ROOT / "agents" / "chainlink-vault-manager.py",
    REPO_ROOT / "agents" / "cross_chain_mvp.py",
    REPO_ROOT / "mining" / "equipment-wallet-connector.py",
]


def _run_sovereign_cycle(tick: int) -> bool:
    """Run the unified sovereign runtime once per swarm tick."""
    try:
        from services.sovereign_runtime import run_cycle

        report = run_cycle(
            state_path=Path(os.environ.get("SOVEREIGN_STATE_PATH", REPO_ROOT / "dashboard" / "state.json")),
            dashboard_path=Path(REPO_ROOT / "dashboard" / "final-monitoring-dashboard-5m.md"),
        )
        print(
            f"[swarm] sovereign cycle {report.get('cycle', tick)} complete "
            f"(tick={report.get('tick')}, apy={report.get('blended_apy')}, "
            f"healthy={report.get('healthy_worker_ratio')})",
            flush=True,
        )
        return True
    except Exception:  # noqa: BLE001
        print(f"[swarm] sovereign cycle failed\n{traceback.format_exc()}", flush=True)
        return False


def _run_module(path: Path) -> bool:
    """Execute a standalone agent script in an isolated module namespace."""
    if not path.exists():
        print(f"[swarm] skip (missing): {path}", flush=True)
        return False
    name = path.stem.replace("-", "_")
    try:
        spec = importlib.util.spec_from_file_location(name, path)
        if spec is None or spec.loader is None:
            print(f"[swarm] skip (no loader): {path}", flush=True)
            return False
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)  # runs the agent's top-level logic
        # If the agent exposes a run()/main()/tick(), call it too.
        for entry in ("tick", "run", "main"):
            fn = getattr(module, entry, None)
            if callable(fn):
                fn()
                break
        return True
    except Exception:  # noqa: BLE001 — sovereign loop must never die on one agent
        print(f"[swarm] agent failed: {path}\n{traceback.format_exc()}", flush=True)
        return False


def _heartbeat(tick: int, ok_count: int, total: int) -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    ts = int(time.time())
    (RUN_DIR / "sovereign.heartbeat").write_text(
        f"tick={tick}\nts={ts}\nagents_ok={ok_count}\nagents_total={total}\n"
    )
    (RUN_DIR / "sovereign.prom").write_text(
        "# HELP yieldswarm_sovereign_tick Sovereign loop tick counter.\n"
        "# TYPE yieldswarm_sovereign_tick counter\n"
        f"yieldswarm_sovereign_tick {tick}\n"
        "# HELP yieldswarm_sovereign_agents_ok Agents that ran cleanly last tick.\n"
        "# TYPE yieldswarm_sovereign_agents_ok gauge\n"
        f"yieldswarm_sovereign_agents_ok {ok_count}\n"
        "# HELP yieldswarm_sovereign_last_run_timestamp Unix ts of last tick.\n"
        "# TYPE yieldswarm_sovereign_last_run_timestamp gauge\n"
        f"yieldswarm_sovereign_last_run_timestamp {ts}\n"
    )


def tick(n: int) -> None:
    print(f"\n[swarm] ===== sovereign tick {n} @ {time.strftime('%Y-%m-%d %H:%M:%S')} =====", flush=True)
    _run_sovereign_cycle(n)
    ok = sum(1 for f in AGENT_FILES if _run_module(f))
    _heartbeat(n, ok, len(AGENT_FILES))
    print(f"[swarm] tick {n} complete: {ok}/{len(AGENT_FILES)} agents ok", flush=True)


def main() -> int:
    print(
        f"[swarm] sovereign loop starting (interval={INTERVAL}s, oneshot={ONESHOT}, "
        f"root={REPO_ROOT})",
        flush=True,
    )
    n = 0
    while True:
        n += 1
        tick(n)
        if ONESHOT:
            return 0
        time.sleep(INTERVAL)


if __name__ == "__main__":
    sys.exit(main())
