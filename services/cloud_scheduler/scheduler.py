"""Central cloud scheduler — cron-driven async orchestrator."""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from services.async_jobs.queue import AsyncJobQueue, JobStatus
from services.cloud_scheduler.decision_engine import WorkloadDecisionEngine
from services.cloud_scheduler.providers import (
    PROVIDER_PRIORITY,
    ProviderState,
    WORKLOAD_DEFAULTS,
    launch_workload,
)
from services.cloud_scheduler.telemetry import UnifiedTelemetry

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


def _current_week() -> int:
    """Week 1–4 of 30-day plan (override with CLOUD_SCHEDULER_WEEK)."""
    override = os.getenv("CLOUD_SCHEDULER_WEEK")
    if override:
        return max(1, min(4, int(override)))
    start = os.getenv("CLOUD_SCHEDULER_START_DATE", "2026-06-15")
    try:
        start_dt = datetime.strptime(start, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        elapsed = (datetime.now(timezone.utc) - start_dt).days
        return max(1, min(4, elapsed // 7 + 1))
    except ValueError:
        return 1


class CloudScheduler:
    """Runs every 5–15 minutes via cron; async-first workload orchestration."""

    def __init__(self) -> None:
        self.dry_run = os.getenv("CLOUD_SCHEDULER_DRY_RUN", "1").lower() in ("1", "true", "yes")
        self.queue = AsyncJobQueue()
        self.telemetry = UnifiedTelemetry()
        self.engine = WorkloadDecisionEngine(week=_current_week())

    def _provider_states(self) -> Dict[str, ProviderState]:
        summary = self.telemetry.provider_summary()
        jobs = self.queue.list_jobs()
        states: Dict[str, ProviderState] = {}
        for name in PROVIDER_PRIORITY:
            p = summary.get(name, {})
            active = sum(
                1 for j in jobs
                if j.provider == name and j.status in (JobStatus.PENDING, JobStatus.RUNNING)
            )
            states[name] = ProviderState(
                name=name,
                active_jobs=active,
                daily_spend_usd=float(p.get("credit_burn_usd", 0)),
                daily_revenue_usd=float(p.get("earnings_usd", 0)),
                healthy=p.get("last_seen", 0) == 0 or (time.time() - p.get("last_seen", 0)) < 3600,
            )
        return states

    def _job_handler(self, job) -> Dict[str, Any]:
        return launch_workload(
            job.provider,
            job.workload,
            job.params,
            dry_run=self.dry_run,
        )

    def tick(self) -> Dict[str, Any]:
        """One scheduler cycle — call from cron every 5–15 min."""
        states = self._provider_states()
        pending = self.queue.list_jobs(JobStatus.PENDING)
        decisions = self.engine.decide(states, queue_depth=len(pending))

        enqueued = []
        for d in decisions:
            if d.action != "scale_up":
                continue
            spec = WORKLOAD_DEFAULTS.get(d.workload, {})
            fallbacks = [p for p in spec.get("providers", []) if p != d.provider]
            job = self.queue.enqueue(
                d.workload,
                d.provider,
                d.params,
                fallback_providers=fallbacks,
            )
            enqueued.append(job.id)

        processed = self.queue.process_pending(self._job_handler, limit=10)

        report = {
            "tick_at": int(time.time()),
            "week": self.engine.week,
            "dry_run": self.dry_run,
            "decisions": [d.to_dict() for d in decisions],
            "enqueued": enqueued,
            "processed_jobs": [j.to_dict() for j in processed],
            "telemetry": self.telemetry.snapshot(),
            "provider_states": {k: {"roi": v.roi, "active": v.active_jobs} for k, v in states.items()},
        }

        out = _run_dir() / "cloud-scheduler-last-tick.json"
        out.write_text(json.dumps(report, indent=2))
        return report


def run_scheduler_tick() -> Dict[str, Any]:
    return CloudScheduler().tick()
