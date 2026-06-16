"""Tests for cloud scheduler + async job queue."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from services.async_jobs.queue import AsyncJobQueue, JobStatus
from services.cloud_scheduler.decision_engine import WorkloadDecisionEngine
from services.cloud_scheduler.providers import ProviderState, best_provider_for_workload
from services.cloud_scheduler.scheduler import CloudScheduler
from services.cloud_scheduler.telemetry import UnifiedTelemetry


def test_async_queue_enqueue_and_process(tmp_path):
    q = AsyncJobQueue(path=tmp_path / "jobs.json")

    def handler(job):
        return {"ok": True, "provider": job.provider}

    job = q.enqueue("bittensor", "akash", {"gpu": "RTX_3090"}, fallback_providers=["vast"])
    assert job.status == JobStatus.PENDING
    done = q.process_pending(handler, limit=5)
    assert len(done) == 1
    assert done[0].status == JobStatus.COMPLETED


def test_async_queue_migration_on_failure(tmp_path):
    q = AsyncJobQueue(path=tmp_path / "jobs.json")
    attempts = {"n": 0}

    def failing_handler(job):
        attempts["n"] += 1
        raise RuntimeError("provider down")

    job = q.enqueue("training", "vast", {}, fallback_providers=["runpod"], max_attempts=1)
    q.process_pending(failing_handler, limit=1)
    updated = q.get(job.id)
    assert updated is not None
    assert updated.status in (JobStatus.FAILED, JobStatus.MIGRATED)


def test_decision_engine_week1():
    engine = WorkloadDecisionEngine(week=1)
    states = {n: ProviderState(name=n) for n in ("akash", "vast", "runpod")}
    decisions = engine.decide(states)
    workloads = {d.workload for d in decisions}
    assert "bittensor" in workloads


def test_telemetry_great_delta_input(tmp_path, monkeypatch):
    monkeypatch.setenv("RUN_DIR", str(tmp_path))
    tel = UnifiedTelemetry()
    tel.ingest_worker("w1", "akash", {"hashrate": 100, "earnings_usd": 50, "credit_burn_usd": 10})
    gd = tel.to_great_delta_input()
    assert gd["gross_revenue_usd"] == 50
    assert gd["credit_burn_usd"] == 10


def test_scheduler_tick(tmp_path, monkeypatch):
    monkeypatch.setenv("RUN_DIR", str(tmp_path))
    monkeypatch.setenv("CLOUD_SCHEDULER_DRY_RUN", "1")
    monkeypatch.setenv("CLOUD_SCHEDULER_WEEK", "1")
    report = CloudScheduler().tick()
    assert "decisions" in report
    assert (tmp_path / "cloud-scheduler-last-tick.json").exists()


def test_best_provider_roi():
    states = {
        "akash": ProviderState(name="akash", daily_revenue_usd=100, daily_spend_usd=5),
        "vast": ProviderState(name="vast", daily_revenue_usd=10, daily_spend_usd=50),
    }
    assert best_provider_for_workload("bittensor", states) == "akash"
