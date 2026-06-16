"""File-based async job queue with retry and provider migration."""

from __future__ import annotations

import json
import os
import time
import uuid
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_dir() -> Path:
    return Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))


class JobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    MIGRATED = "migrated"


@dataclass
class AsyncJob:
    id: str
    workload: str
    provider: str
    params: Dict[str, Any]
    status: JobStatus = JobStatus.PENDING
    attempts: int = 0
    max_attempts: int = 3
    fallback_providers: List[str] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["status"] = self.status.value
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AsyncJob":
        data = dict(data)
        data["status"] = JobStatus(data.get("status", "pending"))
        return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})


class AsyncJobQueue:
    """Durable file queue — no Redis required; Celery-ready interface."""

    def __init__(self, path: Optional[Path] = None):
        self.path = path or (_run_dir() / "async-jobs.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self._write({})

    def _read(self) -> Dict[str, Any]:
        try:
            return json.loads(self.path.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            return {}

    def _write(self, data: Dict[str, Any]) -> None:
        self.path.write_text(json.dumps(data, indent=2))

    def enqueue(
        self,
        workload: str,
        provider: str,
        params: Optional[Dict[str, Any]] = None,
        *,
        fallback_providers: Optional[List[str]] = None,
        max_attempts: int = 3,
    ) -> AsyncJob:
        job = AsyncJob(
            id=uuid.uuid4().hex[:12],
            workload=workload,
            provider=provider,
            params=params or {},
            fallback_providers=fallback_providers or [],
            max_attempts=max_attempts,
        )
        data = self._read()
        data[job.id] = job.to_dict()
        self._write(data)
        return job

    def list_jobs(self, status: Optional[JobStatus] = None) -> List[AsyncJob]:
        jobs = [AsyncJob.from_dict(v) for v in self._read().values()]
        if status:
            jobs = [j for j in jobs if j.status == status]
        return sorted(jobs, key=lambda j: j.created_at)

    def get(self, job_id: str) -> Optional[AsyncJob]:
        raw = self._read().get(job_id)
        return AsyncJob.from_dict(raw) if raw else None

    def _save(self, job: AsyncJob) -> None:
        data = self._read()
        job.updated_at = time.time()
        data[job.id] = job.to_dict()
        self._write(data)

    def process_pending(
        self,
        handler: Callable[[AsyncJob], Dict[str, Any]],
        *,
        limit: int = 10,
    ) -> List[AsyncJob]:
        """Process up to `limit` pending/failed jobs with retry + migration."""
        completed: List[AsyncJob] = []
        pending = self.list_jobs(JobStatus.PENDING) + [
            j for j in self.list_jobs(JobStatus.FAILED) if j.attempts < j.max_attempts
        ]

        for job in pending[:limit]:
            job.status = JobStatus.RUNNING
            job.attempts += 1
            self._save(job)
            try:
                result = handler(job)
                job.status = JobStatus.COMPLETED
                job.result = result
                job.error = None
            except Exception as exc:  # noqa: BLE001
                job.error = str(exc)
                if job.attempts >= job.max_attempts and job.fallback_providers:
                    next_provider = job.fallback_providers.pop(0)
                    job.provider = next_provider
                    job.status = JobStatus.MIGRATED
                    job.attempts = 0
                    job.error = f"migrated after failure: {exc}"
                else:
                    job.status = JobStatus.FAILED
            self._save(job)
            completed.append(job)
        return completed
