#!/usr/bin/env python3
"""Cloud scheduler agent — runs on sovereign tick + dedicated cron."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from services.cloud_scheduler.scheduler import run_scheduler_tick  # noqa: E402


def tick() -> None:
    report = run_scheduler_tick()
    print(
        f"[cloud-scheduler] week={report.get('week')} "
        f"decisions={len(report.get('decisions', []))} "
        f"enqueued={len(report.get('enqueued', []))} "
        f"processed={len(report.get('processed_jobs', []))}"
    )
    gd = report.get("telemetry", {}).get("great_delta", {})
    if gd:
        print(f"[cloud-scheduler] revenue=${gd.get('gross_revenue_usd', 0):.2f} burn=${gd.get('credit_burn_usd', 0):.2f}")


def main() -> int:
    tick()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
