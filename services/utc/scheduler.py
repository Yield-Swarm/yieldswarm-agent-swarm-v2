"""Universal Time Coordinate — monotonic epoch bus for cross-shard scheduling."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List


@dataclass
class TimePulse:
    """Single atomic scheduling tick."""

    utc_epoch: float
    utc_iso: str
    coordinate: int
    pulse_id: int
    shard_hint: int

    def to_dict(self) -> Dict[str, Any]:
        return {
            "utc_epoch": self.utc_epoch,
            "utc_iso": self.utc_iso,
            "coordinate": self.coordinate,
            "pulse_id": self.pulse_id,
            "shard_hint": self.shard_hint,
            "atomic": True,
        }


class UniversalTimeCoordinate:
    """UTC-aligned monotonic coordinate with configurable pulse interval."""

    def __init__(self, pulse_interval_sec: float | None = None):
        self.pulse_interval = float(
            pulse_interval_sec or os.environ.get("ATOMIC_PULSE_INTERVAL", "900")
        )
        self._origin = float(os.environ.get("UTC_ORIGIN_EPOCH", "1704067200"))  # 2024-01-01

    def now(self) -> TimePulse:
        ts = time.time()
        coordinate = int((ts - self._origin) / self.pulse_interval)
        pulse_id = int(ts / self.pulse_interval)
        shard_count = int(os.environ.get("CRON_SHARD_COUNT", "120"))
        return TimePulse(
            utc_epoch=ts,
            utc_iso=datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(),
            coordinate=coordinate,
            pulse_id=pulse_id,
            shard_hint=pulse_id % shard_count,
        )

    def next_pulse_in(self) -> float:
        now = time.time()
        return self.pulse_interval - (now % self.pulse_interval)

    def schedule_window(self, count: int = 5) -> List[Dict[str, Any]]:
        base = self.now()
        return [
            {
                "coordinate": base.coordinate + i,
                "pulse_id": base.pulse_id + i,
                "shard_hint": (base.pulse_id + i) % int(os.environ.get("CRON_SHARD_COUNT", "120")),
            }
            for i in range(count)
        ]
