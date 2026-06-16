#!/usr/bin/env python3
"""Mandelbrot bot — simulates Kairo drives + snapshots Helix Chain into Neon.

Each tick:
  1. Ensures a sim driver exists and ingests signed GPS telemetry (Mandelbrot mesh).
  2. Fetches Helix Chain status from the integration backend.
  3. Logs both streams via services.neon_store (Neon Postgres or JSONL fallback).

Env:
  MANDELBROT_BOT_INTERVAL   Seconds between ticks (default 60)
  MANDELBROT_BOT_DRIVER_ID  Sim driver id (default mandelbrot-bot-001)
  YIELDSWARM_API_BASE       Backend base, e.g. http://127.0.0.1:8080/api
  DATABASE_URL              Neon Postgres connection string (optional)
  MANDELBROT_BOT_ONESHOT    Set 1 for a single tick (tests / cron)
"""

from __future__ import annotations

import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

INTERVAL = int(os.environ.get("MANDELBROT_BOT_INTERVAL", "60"))
DRIVER_ID = os.environ.get("MANDELBROT_BOT_DRIVER_ID", "mandelbrot-bot-001")
API_BASE = os.environ.get(
    "YIELDSWARM_API_BASE",
    os.environ.get("INTEGRATION_API_BASE", "http://127.0.0.1:8080/api"),
).rstrip("/")
ONESHOT = os.environ.get("MANDELBROT_BOT_ONESHOT", "").lower() in ("1", "true", "yes")
STORE_DIR = Path(os.environ.get("KAIRO_STORE_DIR", REPO_ROOT / ".data" / "kairo"))


def _ensure_driver() -> None:
    from kairo.services.identity import DriverStore, generate_driver_identity

    store = DriverStore(STORE_DIR)
    if not store.get(DRIVER_ID):
        store.save(generate_driver_identity(DRIVER_ID))


def _simulate_drive() -> dict:
    """Ingest one signed telemetry packet through the Mandelbrot pipeline."""
    from kairo.client.telemetry import DriverTelemetryClient
    from kairo.services.telemetry_pipeline import TelemetryPipeline

    _ensure_driver()
    pipeline = TelemetryPipeline(STORE_DIR, emit_yieldswarm=True)
    client = DriverTelemetryClient(DRIVER_ID, pipeline=pipeline)

    base_lat = 39.7392 + random.uniform(-0.05, 0.05)
    base_lon = -104.9903 + random.uniform(-0.05, 0.05)
    coords = [
        (base_lat, base_lon),
        (base_lat + 0.008, base_lon + 0.006),
        (base_lat + 0.015, base_lon + 0.012),
    ]

    results = []
    for lat, lon in coords:
        sample = client.collect(
            lat,
            lon,
            speed_kmh=round(random.uniform(28.0, 55.0), 1),
            distance_km=round(random.uniform(0.8, 2.5), 2),
            duration_seconds=random.randint(45, 120),
        )
        results.append(client.submit_sample(sample))

    return results[-1] if results else {}


def _fetch_helix_status() -> dict:
    url = f"{API_BASE}/helix/status"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        return {
            "service": "helix-chain",
            "activated": False,
            "phase": "offline",
            "error": str(exc),
            "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }


def tick(n: int = 1) -> dict:
    from services.neon_store import log_helix, log_mandelbrot

    drive = _simulate_drive()
    mandelbrot_log = {"ok": False}
    if drive.get("accepted"):
        record = {
            "telemetry_id": drive.get("telemetry_id"),
            "driver_id": DRIVER_ID,
            "evm_address": drive.get("contribution", {}).get("evm_address"),
            "signed_at": drive.get("reward_event", {}).get("signed_at"),
            "payload": drive.get("tree", {}),
            "tree": drive.get("tree", {}),
        }
        # Rehydrate from pipeline store for full payload when available
        from kairo.services.mandelbrot_pipeline import MandelbrotPipeline

        stats = MandelbrotPipeline(STORE_DIR).driver_stats(DRIVER_ID) or {}
        if stats:
            record["evm_address"] = stats.get("evm_address")
        mandelbrot_log = log_mandelbrot(
            {
                "telemetry_id": drive["telemetry_id"],
                "driver_id": DRIVER_ID,
                "evm_address": record.get("evm_address"),
                "signed_at": drive.get("reward_event", {}).get("signed_at"),
                "payload": drive,
                "tree": drive.get("tree", {}),
            }
        )

    helix = _fetch_helix_status()
    helix_log = log_helix(helix)

    report = {
        "tick": n,
        "driver_id": DRIVER_ID,
        "mandelbrot_score": drive.get("mandelbrot_score"),
        "shard_id": drive.get("shard_id"),
        "mandelbrot_log": mandelbrot_log,
        "helix_phase": helix.get("phase"),
        "helix_log": helix_log,
    }
    print(json.dumps(report), flush=True)
    return report


def run() -> dict:
    """Single tick — invoked by deploy/runtime/swarm_runner.py each sovereign loop."""
    return tick(1)


def main() -> int:
    if os.environ.get("NEON_AUTO_MIGRATE", "true").lower() in ("1", "true", "yes"):
        try:
            from services.neon_store import ensure_schema

            ensure_schema()
        except Exception as exc:  # noqa: BLE001
            print(json.dumps({"warn": "neon migrate skipped", "error": str(exc)}), flush=True)

    n = 0
    while True:
        n += 1
        tick(n)
        if ONESHOT:
            return 0
        time.sleep(INTERVAL)


if __name__ == "__main__":
    raise SystemExit(main())
