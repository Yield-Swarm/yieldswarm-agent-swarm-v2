"""Astrological Schedule Engine — Aquarius season multipliers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Any, Dict


# Tropical Aquarius: Jan 20 – Feb 18 (operator calendar; precession override via env)
AQUARIUS_START = (1, 20)
AQUARIUS_END = (2, 18)


@dataclass
class AstroWindow:
    sign: str
    in_season: bool
    multiplier_bps: int
    day_of_year: int
    lunar_phase_stub: float

    def to_dict(self) -> Dict[str, Any]:
        return {
            "sign": self.sign,
            "in_season": self.in_season,
            "multiplier_bps": self.multiplier_bps,
            "day_of_year": self.day_of_year,
            "lunar_phase_stub": self.lunar_phase_stub,
        }


class AstrologicalScheduleEngine:
    """Gates cron/reward multipliers by zodiac season."""

    def __init__(self, aquarius_bps: int = 150):
        self.aquarius_bps = aquarius_bps

    def _in_aquarius(self, d: date) -> bool:
        m, day = d.month, d.day
        if m == 1 and day >= AQUARIUS_START[1]:
            return True
        if m == 2 and day <= AQUARIUS_END[1]:
            return True
        return False

    def evaluate(self, when: datetime | None = None) -> AstroWindow:
        now = when or datetime.now(timezone.utc)
        d = now.date()
        in_aquarius = self._in_aquarius(d)
        doy = d.timetuple().tm_yday
        lunar = (doy % 29.53) / 29.53
        multiplier = self.aquarius_bps if in_aquarius else 100
        return AstroWindow(
            sign="aquarius" if in_aquarius else "off_season",
            in_season=in_aquarius,
            multiplier_bps=multiplier,
            day_of_year=doy,
            lunar_phase_stub=round(lunar, 3),
        )
