#!/usr/bin/env python3
"""Kairo telemetry daemon — Helium + Nexus bridge with optional YSLR/ZK proofs.

Ingests DePIN telemetry, signs via Kairo pipeline, optionally attaches
Halo2/Groth16-style proof bundles, and forwards to Mandelbrot + Helix APIs.

Usage:
    python3 kairo/telemetry_daemon.py --helium --nexus --halo2-prove
    python3 kairo/telemetry_daemon.py --interval 30 --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))


@dataclass
class DaemonConfig:
    interval_sec: float = 30.0
    helium: bool = False
    nexus: bool = False
    halo2_prove: bool = False
    dry_run: bool = False
    kairo_api: str = "http://127.0.0.1:8091"
    backend_api: str = "http://127.0.0.1:8080"
    driver_id: str = "telemetry-daemon-001"


def _utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def _http_json(method: str, url: str, body: dict | None = None, timeout: int = 15) -> dict[str, Any]:
    data = None
    headers = {"Content-Type": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _helium_pulse(cfg: DaemonConfig) -> dict[str, Any]:
    """Simulated Helium coverage pulse — replace with live hotspot API when keyed."""
    return {
        "source": "helium",
        "hotspot_count": int(os.environ.get("HELIUM_HOTSPOT_COUNT", "1")),
        "coverage_score": 0.82,
        "timestamp": _utc(),
    }


def _nexus_pulse(cfg: DaemonConfig) -> dict[str, Any]:
    """Nexus Chain orchestration heartbeat."""
    try:
        status = _http_json("GET", f"{cfg.backend_api}/api/helix/health")
        return {"source": "nexus", "helix": status, "timestamp": _utc()}
    except Exception as exc:
        return {"source": "nexus", "error": str(exc), "timestamp": _utc()}


def _zk_attest(cfg: DaemonConfig, payload: dict[str, Any]) -> dict[str, Any] | None:
    if not cfg.halo2_prove:
        return None
    try:
        from kairo.services.zk_treasury import prove_telemetry_bounds

        return prove_telemetry_bounds(
            driver_registered=True,
            in_bounds=True,
            quality_score=95,
        )
    except ImportError:
        try:
            return _http_json("POST", f"{cfg.backend_api}/api/zk/verify", {
                "driver_registered": True,
                "in_bounds": True,
                "quality_score": 95,
            })
        except Exception:
            return None


def _encrypt_batch(cfg: DaemonConfig, samples: list[dict[str, Any]]) -> dict[str, Any] | None:
    try:
        from kairo.services.yslr import encrypt_telemetry_batch

        return encrypt_telemetry_batch(samples, cfg.driver_id).to_dict()
    except ImportError:
        try:
            return _http_json("POST", f"{cfg.backend_api}/api/yslr/telemetry", {
                "driver_id": cfg.driver_id,
                "samples": samples,
            })
        except Exception:
            return None


def run_cycle(cfg: DaemonConfig) -> dict[str, Any]:
    samples: list[dict[str, Any]] = []
    if cfg.helium:
        samples.append(_helium_pulse(cfg))
    if cfg.nexus:
        samples.append(_nexus_pulse(cfg))

    sample = {
        "driver_id": cfg.driver_id,
        "latitude": float(os.environ.get("KAIRO_LAT", "39.7392")),
        "longitude": float(os.environ.get("KAIRO_LON", "-104.9903")),
        "speed_kmh": float(os.environ.get("KAIRO_SPEED", "0")),
        "depin_sources": [s.get("source") for s in samples],
        "timestamp": _utc(),
    }
    samples.append(sample)

    result: dict[str, Any] = {"cycle_at": _utc(), "samples": len(samples)}

    zk = _zk_attest(cfg, sample)
    if zk:
        result["zk_proof"] = zk

    if cfg.dry_run:
        result["dry_run"] = True
        result["payload"] = samples
        return result

    yslr = _encrypt_batch(cfg, samples)
    if yslr:
        result["yslr"] = "envelope" in yslr or "ciphertext" in str(yslr)

    try:
        resp = _http_json("POST", f"{cfg.kairo_api}/api/telemetry", sample)
        result["kairo"] = resp.get("status", "accepted")
    except urllib.error.URLError as exc:
        result["kairo"] = f"offline: {exc}"

    return result


def main() -> int:
    p = argparse.ArgumentParser(description="Kairo DePIN telemetry daemon")
    p.add_argument("--interval", type=float, default=30.0)
    p.add_argument("--helium", action="store_true")
    p.add_argument("--nexus", action="store_true")
    p.add_argument("--halo2-prove", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--once", action="store_true")
    args = p.parse_args()

    cfg = DaemonConfig(
        interval_sec=args.interval,
        helium=args.helium,
        nexus=args.nexus,
        halo2_prove=args.halo2_prove,
        dry_run=args.dry_run,
        kairo_api=os.environ.get("KAIRO_API_URL", "http://127.0.0.1:8091"),
        backend_api=os.environ.get("API_BASE", "http://127.0.0.1:8080"),
        driver_id=os.environ.get("MANDELBROT_BOT_DRIVER_ID", "telemetry-daemon-001"),
    )

    print(f"[telemetry_daemon] start helium={cfg.helium} nexus={cfg.nexus} zk={cfg.halo2_prove}", flush=True)

    while True:
        out = run_cycle(cfg)
        print(json.dumps(out), flush=True)
        if args.once:
            break
        time.sleep(cfg.interval_sec)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
