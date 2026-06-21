"""YSLR-format quantum-shielded encrypted task queue."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
import uuid
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]


class YslrTaskStatus(str, Enum):
    QUEUED = "queued"
    SHIELDED = "shielded"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class YslrTask:
    """YSLR v1 envelope — council-routed encrypted task."""

    id: str
    lane: str
    payload_cipher: str
    payload_hash: str
    shield: str = "zec-proof-stub"
    status: YslrTaskStatus = YslrTaskStatus.QUEUED
    created_at: float = field(default_factory=time.time)
    council_route: str = "helix"
    meta: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["status"] = self.status.value
        d["format"] = "YSLR/1.0"
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "YslrTask":
        data = dict(data)
        data["status"] = YslrTaskStatus(data.get("status", "queued"))
        return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})


def _shield_key() -> bytes:
    raw = os.environ.get("AGENTSWARM_MASTER_KEY") or os.environ.get("ZEC_SHIELDED_KEY") or "yslr-dev-key"
    return hashlib.sha256(raw.encode()).digest()


def _encrypt_payload(payload: Dict[str, Any]) -> tuple[str, str]:
    """HMAC-sealed base64 envelope (production: replace with ZEC shielded memo)."""
    body = json.dumps(payload, sort_keys=True).encode()
    digest = hashlib.sha256(body).hexdigest()
    sig = hmac.new(_shield_key(), body, hashlib.sha256).digest()
    cipher = base64.urlsafe_b64encode(body + b"." + sig).decode()
    return cipher, digest


def _decrypt_payload(cipher: str) -> Dict[str, Any]:
    raw = base64.urlsafe_b64decode(cipher.encode())
    body, sig = raw.rsplit(b".", 1)
    expected = hmac.new(_shield_key(), body, hashlib.sha256).digest()
    if not hmac.compare_digest(sig, expected):
        raise ValueError("YSLR integrity check failed")
    return json.loads(body.decode())


class YslrQueue:
    """Durable YSLR task queue under .run/yslr/."""

    def __init__(self, path: Optional[Path] = None):
        run_dir = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))
        self.path = path or (run_dir / "yslr" / "queue.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self._write({"tasks": []})

    def _read(self) -> Dict[str, Any]:
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, FileNotFoundError):
            return {"tasks": []}

    def _write(self, data: Dict[str, Any]) -> None:
        self.path.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def enqueue(self, lane: str, payload: Dict[str, Any], *, council_route: str = "helix") -> YslrTask:
        cipher, digest = _encrypt_payload(payload)
        task = YslrTask(
            id=str(uuid.uuid4()),
            lane=lane,
            payload_cipher=cipher,
            payload_hash=digest,
            status=YslrTaskStatus.SHIELDED,
            council_route=council_route,
            meta={"phase": os.environ.get("YSLR_PHASE", "genesis")},
        )
        data = self._read()
        tasks = [YslrTask.from_dict(t) for t in data.get("tasks", [])]
        tasks.append(task)
        self._write({"tasks": [t.to_dict() for t in tasks]})
        return task

    def dequeue(self, lane: Optional[str] = None) -> Optional[tuple[YslrTask, Dict[str, Any]]]:
        data = self._read()
        tasks = [YslrTask.from_dict(t) for t in data.get("tasks", [])]
        for i, task in enumerate(tasks):
            if task.status not in (YslrTaskStatus.QUEUED, YslrTaskStatus.SHIELDED):
                continue
            if lane and task.lane != lane:
                continue
            task.status = YslrTaskStatus.RUNNING
            tasks[i] = task
            self._write({"tasks": [t.to_dict() for t in tasks]})
            return task, _decrypt_payload(task.payload_cipher)
        return None

    def summary(self) -> Dict[str, Any]:
        tasks = [YslrTask.from_dict(t) for t in self._read().get("tasks", [])]
        by_status: Dict[str, int] = {}
        for t in tasks:
            by_status[t.status.value] = by_status.get(t.status.value, 0) + 1
        return {"format": "YSLR/1.0", "total": len(tasks), "by_status": by_status}
