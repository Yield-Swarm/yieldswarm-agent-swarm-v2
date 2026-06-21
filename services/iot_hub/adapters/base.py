from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


@dataclass
class CheckResult:
    device_id: str
    status: str
    latency_ms: float | None = None
    message: str = ""
    metrics: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "device_id": self.device_id,
            "status": self.status,
            "latency_ms": self.latency_ms,
            "message": self.message,
            "metrics": self.metrics,
        }


class DeviceAdapter(ABC):
    device_type: str = "unknown"

    @abstractmethod
    def check(self, device: dict[str, Any], *, dry_run: bool = False) -> CheckResult:
        raise NotImplementedError
