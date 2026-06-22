#!/usr/bin/env python3
"""
sys_profile.py — Local host telemetry for Cherry Servers credits validation.

Collects CPU, RAM, storage, GPU (nvidia-smi), and utilization estimates.
Persists snapshots to .run/sys_profile_snapshots.jsonl for rolling 30-day averages.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

SNAPSHOT_RETENTION_DAYS = 30


def ensure_psutil():
    try:
        import psutil  # noqa: F401
    except ImportError:
        print("[!] Installing required 'psutil' package via pip...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "pip", "install", "psutil", "-q"])
    import psutil

    return psutil


def repo_run_dir() -> Path:
    script = Path(__file__).resolve()
    repo_root = script.parents[2]
    run_dir = Path(os.environ.get("RUN_DIR", repo_root / ".run"))
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def snapshot_path() -> Path:
    return repo_run_dir() / "sys_profile_snapshots.jsonl"


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def read_cpu_model(psutil_mod) -> dict[str, Any]:
    arch = platform.machine()
    physical = psutil_mod.cpu_count(logical=False) or 0
    logical = psutil_mod.cpu_count(logical=True) or 0
    model = platform.processor() or "unknown"

    if platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if "model name" in line.lower():
                        model = line.split(":", 1)[1].strip()
                        break
        except OSError:
            pass

    return {
        "architecture": arch,
        "model": model,
        "physical_cores": physical,
        "logical_cores": logical,
    }


def read_memory(psutil_mod) -> dict[str, Any]:
    vm = psutil_mod.virtual_memory()
    return {
        "total_gb": round(vm.total / (1024**3), 2),
        "available_gb": round(vm.available / (1024**3), 2),
        "used_percent": vm.percent,
    }


def read_storage(psutil_mod) -> list[dict[str, Any]]:
    mounts: list[dict[str, Any]] = []
    for part in psutil_mod.disk_partitions(all=False):
        if part.fstype in ("", "tmpfs", "devtmpfs", "squashfs"):
            continue
        try:
            usage = psutil_mod.disk_usage(part.mountpoint)
        except (OSError, PermissionError):
            continue
        mounts.append(
            {
                "mount": part.mountpoint,
                "device": part.device,
                "fstype": part.fstype,
                "total_gb": round(usage.total / (1024**3), 2),
                "free_gb": round(usage.free / (1024**3), 2),
                "used_percent": usage.percent,
            }
        )
    return mounts


def read_gpus() -> list[dict[str, Any]]:
    try:
        raw = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=index,name,memory.total,memory.used,utilization.gpu,utilization.memory",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=10,
        ).strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        return []

    gpus: list[dict[str, Any]] = []
    for line in raw.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 6:
            continue
        gpus.append(
            {
                "index": int(parts[0]),
                "name": parts[1],
                "vram_total_mb": float(parts[2]),
                "vram_used_mb": float(parts[3]),
                "gpu_util_percent": float(parts[4]),
                "vram_util_percent": float(parts[5]),
            }
        )
    return gpus


def read_live_utilization(psutil_mod) -> dict[str, Any]:
    cpu_percent = psutil_mod.cpu_percent(interval=1.0)
    mem = psutil_mod.virtual_memory()
    load1, load5, load15 = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
    uptime_seconds = max(0, int(time.time() - psutil_mod.boot_time()))
    return {
        "cpu_percent": cpu_percent,
        "memory_percent": mem.percent,
        "load_avg_1m": round(load1, 2),
        "load_avg_5m": round(load5, 2),
        "load_avg_15m": round(load15, 2),
        "uptime_seconds": uptime_seconds,
    }


def try_sar_averages(days: int) -> dict[str, Any] | None:
    if not shutil_which("sar"):
        return None
    try:
        cpu_out = subprocess.check_output(
            ["sar", "-u", f"-{days}"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=20,
        )
        mem_out = subprocess.check_output(
            ["sar", "-r", f"-{days}"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=20,
        )
    except (subprocess.SubprocessError, FileNotFoundError):
        return None

    cpu_avg = None
    for line in cpu_out.splitlines():
        if line.strip().startswith("Average:"):
            cols = line.split()
            if len(cols) >= 4:
                # %user %nice %system %iowait ...
                try:
                    user = float(cols[2])
                    system = float(cols[4])
                    iowait = float(cols[5]) if len(cols) > 5 else 0.0
                    cpu_avg = round(user + system + iowait, 2)
                except ValueError:
                    pass

    mem_avg_percent = None
    for line in mem_out.splitlines():
        if line.strip().startswith("Average:"):
            cols = line.split()
            if len(cols) >= 5:
                try:
                    mem_used = float(cols[3])
                    mem_free = float(cols[4])
                    total = mem_used + mem_free
                    if total > 0:
                        mem_avg_percent = round((mem_used / total) * 100, 2)
                except ValueError:
                    pass

    if cpu_avg is None and mem_avg_percent is None:
        return None

    return {
        "source": "sar",
        "window_days": days,
        "cpu_percent_avg": cpu_avg,
        "memory_percent_avg": mem_avg_percent,
    }


def shutil_which(cmd: str) -> str | None:
    from shutil import which

    return which(cmd)


def load_snapshots(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def prune_snapshots(rows: list[dict[str, Any]], days: int) -> list[dict[str, Any]]:
    cutoff = utc_now() - timedelta(days=days)
    kept: list[dict[str, Any]] = []
    for row in rows:
        ts = row.get("timestamp_utc")
        if not ts:
            continue
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        except ValueError:
            continue
        if dt >= cutoff:
            kept.append(row)
    return kept


def average_snapshots(rows: list[dict[str, Any]], days: int) -> dict[str, Any] | None:
    cutoff = utc_now() - timedelta(days=days)
    cpu_vals: list[float] = []
    mem_vals: list[float] = []
    gpu_vals: list[float] = []

    for row in rows:
        ts = row.get("timestamp_utc")
        if not ts:
            continue
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        except ValueError:
            continue
        if dt < cutoff:
            continue
        live = row.get("live", {})
        if isinstance(live.get("cpu_percent"), (int, float)):
            cpu_vals.append(float(live["cpu_percent"]))
        if isinstance(live.get("memory_percent"), (int, float)):
            mem_vals.append(float(live["memory_percent"]))
        for gpu in row.get("gpus", []):
            if isinstance(gpu.get("gpu_util_percent"), (int, float)):
                gpu_vals.append(float(gpu["gpu_util_percent"]))

    if not cpu_vals and not mem_vals and not gpu_vals:
        return None

    def avg(vals: list[float]) -> float | None:
        return round(sum(vals) / len(vals), 2) if vals else None

    return {
        "source": "snapshot_history",
        "window_days": days,
        "samples": max(len(cpu_vals), len(mem_vals), len(gpu_vals)),
        "cpu_percent_avg": avg(cpu_vals),
        "memory_percent_avg": avg(mem_vals),
        "gpu_util_percent_avg": avg(gpu_vals),
    }


def append_snapshot(path: Path, payload: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(payload, separators=(",", ":")) + "\n")


def rewrite_snapshots(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, separators=(",", ":")) + "\n")


def detect_environment() -> str:
    if os.environ.get("RUNPOD_POD_ID"):
        return "runpod"
    if os.environ.get("K_SERVICE") or os.environ.get("GOOGLE_CLOUD_PROJECT"):
        return "gcp"
    if os.environ.get("WEBSITE_SITE_NAME") or os.environ.get("AZURE_SUBSCRIPTION_ID"):
        return "azure"
    if os.environ.get("HAJI_CLOUD") or os.environ.get("HAJI_WORKER_ID"):
        return "haji"
    return "local"


def build_profile(days: int = 30, save_snapshot: bool = True) -> dict[str, Any]:
    psutil_mod = ensure_psutil()
    live = read_live_utilization(psutil_mod)
    gpus = read_gpus()

    snap_file = snapshot_path()
    history = prune_snapshots(load_snapshots(snap_file), SNAPSHOT_RETENTION_DAYS)

    snapshot = {
        "timestamp_utc": utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "hostname": platform.node(),
        "environment": detect_environment(),
        "cpu": read_cpu_model(psutil_mod),
        "memory": read_memory(psutil_mod),
        "storage": read_storage(psutil_mod),
        "gpus": gpus,
        "live": live,
    }

    if save_snapshot:
        append_snapshot(snap_file, snapshot)
        history.append(snapshot)
        rewrite_snapshots(snap_file, prune_snapshots(history, SNAPSHOT_RETENTION_DAYS))

    utilization_30d = try_sar_averages(days) or average_snapshots(history, days)
    if utilization_30d is None:
        utilization_30d = {
            "source": "live_fallback",
            "window_days": days,
            "note": "No sar logs or snapshot history — using current live readings",
            "cpu_percent_avg": live["cpu_percent"],
            "memory_percent_avg": live["memory_percent"],
            "gpu_util_percent_avg": (
                round(sum(g["gpu_util_percent"] for g in gpus) / len(gpus), 2) if gpus else None
            ),
            "uptime_seconds": live["uptime_seconds"],
        }

    return {
        "report_title": "Cherry Servers Setup & Test Credits Validation",
        "recipient": "Justas | CherryServers",
        "generated_at_utc": utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "host": {
            "hostname": platform.node(),
            "os": f"{platform.system()} {platform.release()}",
            "environment": detect_environment(),
        },
        "cpu": snapshot["cpu"],
        "memory": snapshot["memory"],
        "storage": snapshot["storage"],
        "gpus": gpus,
        "live": live,
        "utilization_30d": utilization_30d,
    }


def render_markdown(profile: dict[str, Any]) -> str:
    cpu = profile["cpu"]
    mem = profile["memory"]
    root = next((d for d in profile["storage"] if d["mount"] == "/"), profile["storage"][0] if profile["storage"] else {})
    util = profile["utilization_30d"]
    gpu_text = "No dedicated GPU detected / N/A"
    if profile["gpus"]:
        parts = []
        for g in profile["gpus"]:
            parts.append(
                f"{g['name']} ({g['vram_total_mb']:.0f}MB VRAM) @ {g['gpu_util_percent']:.0f}% GPU / {g['vram_util_percent']:.0f}% VRAM"
            )
        gpu_text = "; ".join(parts)

    def fmt_pct(val: Any) -> str:
        return f"{val}%" if isinstance(val, (int, float)) else "n/a"

    lines = [
        "### System Specifications & Live Metrics Matrix",
        "",
        "| Metric Feature | Target Instance Environment Values |",
        "| :--- | :--- |",
        f"| **Host / Environment** | {profile['host']['hostname']} ({profile['host']['environment']}) |",
        f"| **Host Machine OS** | {profile['host']['os']} |",
        f"| **Processor / CPU Type** | {cpu['model']} ({cpu['logical_cores']} logical / {cpu['physical_cores']} physical, {cpu['architecture']}) |",
        f"| **System Memory (RAM)** | Total: {mem['total_gb']} GB, Available: {mem['available_gb']} GB (Current: {mem['used_percent']}%) |",
        f"| **Root Disk Storage** | Total: {root.get('total_gb', 'n/a')} GB, Free: {root.get('free_gb', 'n/a')} GB (Current: {root.get('used_percent', 'n/a')}%) |",
        f"| **Graphics Card (GPU)** | {gpu_text} |",
        f"| **Live CPU Utilization** | {profile['live']['cpu_percent']}% |",
        f"| **30d Utilization ({util.get('source', 'unknown')})** | CPU avg: {fmt_pct(util.get('cpu_percent_avg'))}, RAM avg: {fmt_pct(util.get('memory_percent_avg'))}, GPU avg: {fmt_pct(util.get('gpu_util_percent_avg'))} |",
        "",
        "*Generated successfully for Cherry Servers Onboarding & Infrastructure Validation.*",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Local host telemetry for Cherry Servers")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of Markdown")
    parser.add_argument("--days", type=int, default=30, help="Utilization window in days")
    parser.add_argument("--no-snapshot", action="store_true", help="Do not persist snapshot history")
    args = parser.parse_args()

    profile = build_profile(days=args.days, save_snapshot=not args.no_snapshot)
    if args.json:
        print(json.dumps(profile, indent=2))
    else:
        print(render_markdown(profile))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
