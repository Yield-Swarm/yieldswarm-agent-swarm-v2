"""Base miner interface for unified mining manager."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

from mining.config import MiningConfig


class MinerState(str, Enum):
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    ERROR = "error"
    DRY_RUN = "dry_run"


@dataclass
class MinerStatus:
    name: str
    state: MinerState
    pid: Optional[int] = None
    wallet: str = ""
    message: str = ""
    metrics: Dict[str, Any] = field(default_factory=dict)
    updated_at: float = field(default_factory=time.time)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "state": self.state.value,
            "pid": self.pid,
            "wallet": self.wallet,
            "message": self.message,
            "metrics": self.metrics,
            "updated_at": self.updated_at,
        }


class BaseMiner(ABC):
    name: str = "base"

    def __init__(self, config: MiningConfig, run_dir: Path):
        self.config = config
        self.run_dir = run_dir
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.pid_file = self.run_dir / f"{self.name}.pid"
        self.status_file = self.run_dir / f"{self.name}-status.json"
        self.config_file = self.run_dir / f"{self.name}-config.json"

    @abstractmethod
    def validate(self) -> Optional[str]:
        """Return error message if misconfigured."""

    @abstractmethod
    def build_config(self) -> Dict[str, Any]:
        """Generate miner-specific config artifact."""

    @abstractmethod
    def start_command(self) -> List[str]:
        """Command argv to start the miner process."""

    def _read_pid(self) -> Optional[int]:
        if not self.pid_file.exists():
            return None
        try:
            return int(self.pid_file.read_text().strip())
        except ValueError:
            return None

    def _is_pid_alive(self, pid: int) -> bool:
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

    def _write_status(self, status: MinerStatus) -> None:
        self.status_file.write_text(json.dumps(status.to_dict(), indent=2))

    def status(self) -> MinerStatus:
        pid = self._read_pid()
        if pid and self._is_pid_alive(pid):
            return MinerStatus(
                name=self.name,
                state=MinerState.RUNNING,
                pid=pid,
                wallet=self._wallet_display(),
                message="process alive",
            )
        if self.config.dry_run and self.status_file.exists():
            try:
                data = json.loads(self.status_file.read_text())
                if data.get("state") == MinerState.DRY_RUN.value:
                    return MinerStatus(**{**data, "state": MinerState.DRY_RUN})
            except (json.JSONDecodeError, TypeError):
                pass
        return MinerStatus(
            name=self.name,
            state=MinerState.STOPPED,
            wallet=self._wallet_display(),
            message="not running",
        )

    def start(self) -> MinerStatus:
        err = self.validate()
        if err:
            st = MinerStatus(name=self.name, state=MinerState.ERROR, message=err, wallet=self._wallet_display())
            self._write_status(st)
            return st

        existing = self.status()
        if existing.state == MinerState.RUNNING:
            return existing

        cfg = self.build_config()
        self.config_file.write_text(json.dumps(cfg, indent=2))

        if self.config.dry_run:
            st = MinerStatus(
                name=self.name,
                state=MinerState.DRY_RUN,
                wallet=self._wallet_display(),
                message="dry-run: config written, process not spawned",
                metrics={"config_path": str(self.config_file)},
            )
            self._write_status(st)
            return st

        cmd = self.start_command()
        if not cmd:
            st = MinerStatus(name=self.name, state=MinerState.ERROR, message="empty start command")
            self._write_status(st)
            return st

        log_path = self.run_dir / f"{self.name}.log"
        with open(log_path, "a", encoding="utf-8") as logf:
            proc = subprocess.Popen(
                cmd,
                stdout=logf,
                stderr=subprocess.STDOUT,
                cwd=str(self.run_dir),
                start_new_session=True,
            )
        self.pid_file.write_text(str(proc.pid))
        st = MinerStatus(
            name=self.name,
            state=MinerState.STARTING,
            pid=proc.pid,
            wallet=self._wallet_display(),
            message=f"started: {' '.join(cmd[:3])}...",
            metrics={"log": str(log_path)},
        )
        self._write_status(st)
        return st

    def stop(self) -> MinerStatus:
        pid = self._read_pid()
        if pid and self._is_pid_alive(pid):
            try:
                os.killpg(os.getpgid(pid), signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
        if self.pid_file.exists():
            self.pid_file.unlink()
        st = MinerStatus(name=self.name, state=MinerState.STOPPED, wallet=self._wallet_display(), message="stopped")
        self._write_status(st)
        return st

    @abstractmethod
    def _wallet_display(self) -> str:
        ...
