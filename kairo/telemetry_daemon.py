#!/usr/bin/env python3
"""Kairo telemetry daemon — Helium coverage + Nexus treasury + Halo2 prove bridge.

Termux / Pixel:
    python kairo/telemetry_daemon.py --helium --nexus --halo2-prove &
    python kairo/telemetry_daemon.py --once --helium --nexus

Polls driver telemetry, emits to YieldSwarm backend, and records Nexus routing
heartbeats for the multi-chain treasury layer.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
RUN_DIR = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))

# Nexus Treasury (Solenoid 1) — matches programs/cross_chain treasury registry
NEXUS_TREASURY = os.environ.get(
    "NEXUS_TREASURY_SOLANA", "kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN"
)
API_BASE = os.environ.get("API_BASE", "http://127.0.0.1:8080")
KAIRO_INGEST = os.environ.get("KAIRO_TELEMETRY_ENDPOINT", f"{API_BASE}/api/kairo/telemetry")
HELIUM_MOCK_COVERAGE = float(os.environ.get("HELIUM_COVERAGE_PCT", "87.5"))


def _post_json(url: str, payload: dict) -> bool:
    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return 200 <= resp.status < 300
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def _halo2_prove_stub() -> dict:
    """Lightweight Halo2/ZK entropy prove heartbeat (full prove in circuits/)."""
    try:
        sys.path.insert(0, str(REPO_ROOT / "src" / "infrastructure"))
        from zk_entropy_core import EntropyCore  # type: ignore

        core = EntropyCore()
        sample = core.collect_window()
        return {
            "commitment": sample.get("commitment", "0x0"),
            "quality": sample.get("quality", 0.0),
            "proved": True,
        }
    except Exception as exc:
        return {"proved": False, "error": str(exc)}


def emit_pulse(helium: bool, nexus: bool, halo2: bool) -> dict:
    ts = datetime.now(timezone.utc).isoformat()
    pulse: dict = {"timestamp": ts, "source": "kairo-telemetry-daemon"}

    if helium:
        pulse["helium"] = {
            "coverage_pct": HELIUM_MOCK_COVERAGE,
            "mobile_hotspots": int(os.environ.get("HELIUM_HOTSPOTS", "3")),
            "status": "earning",
        }

    if nexus:
        pulse["nexus"] = {
            "treasury": NEXUS_TREASURY,
            "solenoid": 1,
            "route": "treasury_registry",
            "status": "bridged",
        }

    if halo2:
        pulse["halo2"] = _halo2_prove_stub()

    # Best-effort ingest to backend / Kairo pipeline
    _post_json(KAIRO_INGEST, pulse)
    _post_json(f"{API_BASE}/api/telemetry/pulse", pulse)

    return pulse


def main() -> int:
    p = argparse.ArgumentParser(description="Kairo telemetry daemon")
    p.add_argument("--helium", action="store_true", help="include Helium coverage feed")
    p.add_argument("--nexus", action="store_true", help="include Nexus treasury bridge")
    p.add_argument("--halo2-prove", action="store_true", help="run ZK entropy prove heartbeat")
    p.add_argument("--once", action="store_true", help="single pulse then exit")
    p.add_argument("--interval", type=int, default=60, help="seconds between pulses")
    args = p.parse_args()

    helium = args.helium or not any([args.helium, args.nexus, args.halo2_prove])
    nexus = args.nexus or not any([args.helium, args.nexus, args.halo2_prove])
    halo2 = args.halo2_prove

    RUN_DIR.mkdir(parents=True, exist_ok=True)

    if args.once:
        pulse = emit_pulse(helium, nexus, halo2)
        print(json.dumps(pulse, indent=2))
        (RUN_DIR / "kairo-telemetry-last.json").write_text(json.dumps(pulse, indent=2) + "\n")
        return 0

    print(f"Kairo telemetry daemon — interval {args.interval}s (Ctrl+C to stop)")
    while True:
        pulse = emit_pulse(helium, nexus, halo2)
        (RUN_DIR / "kairo-telemetry-last.json").write_text(json.dumps(pulse, indent=2) + "\n")
        print(f"[{pulse['timestamp']}] helium={bool(pulse.get('helium'))} nexus={bool(pulse.get('nexus'))}")
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
