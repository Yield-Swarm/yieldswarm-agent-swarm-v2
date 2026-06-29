"""Astronomical house assignment — Western + Eastern charts → 24 Houses."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, time
from typing import Any


WESTERN_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
]

EASTERN_ANIMALS = [
    "Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake",
    "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig",
]

HOUSES = [
    {"id": 1, "name": "House of Solar Forge", "vector": "north"},
    {"id": 2, "name": "House of Lunar Tide", "vector": "northeast"},
    {"id": 3, "name": "House of Mercurial Spark", "vector": "east"},
    {"id": 4, "name": "House of Venusian Grove", "vector": "southeast"},
    {"id": 5, "name": "House of Martial Blade", "vector": "south"},
    {"id": 6, "name": "House of Jovian Crown", "vector": "southwest"},
    {"id": 7, "name": "House of Saturnine Gate", "vector": "west"},
    {"id": 8, "name": "House of Uranian Storm", "vector": "northwest"},
    {"id": 9, "name": "House of Neptunian Deep", "vector": "zenith"},
    {"id": 10, "name": "House of Plutonian Core", "vector": "nadir"},
    {"id": 11, "name": "House of Stellar Bridge", "vector": "ascendant"},
    {"id": 12, "name": "House of Galactic Spindle", "vector": "descendant"},
    {"id": 13, "name": "House of Eastern Dragon", "vector": "dragon"},
    {"id": 14, "name": "House of Western Phoenix", "vector": "phoenix"},
    {"id": 15, "name": "House of Equinox Balance", "vector": "equinox"},
    {"id": 16, "name": "House of Solstice Flame", "vector": "solstice"},
    {"id": 17, "name": "House of Helical Spire", "vector": "helix"},
    {"id": 18, "name": "House of Runic Anvil", "vector": "rune"},
    {"id": 19, "name": "House of Deific Echo", "vector": "deity"},
    {"id": 20, "name": "House of Mesh Weaver", "vector": "mesh"},
    {"id": 21, "name": "House of Yield Current", "vector": "yield"},
    {"id": 22, "name": "House of Sovereign Ranch", "vector": "ranch"},
    {"id": 23, "name": "House of Akash Wind", "vector": "akash"},
    {"id": 24, "name": "House of Cherry Forge", "vector": "cherry"},
]


@dataclass
class BirthMetrics:
    birth_date: date
    birth_time: time
    latitude: float
    longitude: float


class AstrologyEngine:
    """Map birth metrics to one of 24 custom Houses."""

    def western_sign(self, birth_date: date) -> str:
        month, day = birth_date.month, birth_date.day
        boundaries = [
            (3, 21, 0), (4, 20, 1), (5, 21, 2), (6, 21, 3),
            (7, 23, 4), (8, 23, 5), (9, 23, 6), (10, 23, 7),
            (11, 22, 8), (12, 22, 9), (1, 20, 10), (2, 19, 11),
        ]
        idx = 11
        for m, d, i in boundaries:
            if (month == m and day >= d) or (month == (m % 12) + 1 and month != m):
                idx = i
                break
        return WESTERN_SIGNS[idx]

    def eastern_animal(self, birth_date: date) -> str:
        year = birth_date.year
        return EASTERN_ANIMALS[(year - 4) % 12]

    def sidereal_offset(self, metrics: BirthMetrics) -> float:
        dt = datetime.combine(metrics.birth_date, metrics.birth_time)
        day_of_year = dt.timetuple().tm_yday
        hour_angle = metrics.birth_time.hour + metrics.birth_time.minute / 60.0
        return (day_of_year * 15.0 + hour_angle + metrics.longitude) % 360.0

    def assign_house(self, metrics: BirthMetrics) -> dict[str, Any]:
        western = self.western_sign(metrics.birth_date)
        eastern = self.eastern_animal(metrics.birth_date)
        offset = self.sidereal_offset(metrics)
        western_idx = WESTERN_SIGNS.index(western)
        eastern_idx = EASTERN_ANIMALS.index(eastern)
        lat_factor = int(abs(metrics.latitude) / 15) % 12
        house_idx = (western_idx + eastern_idx + lat_factor + int(offset / 30)) % 24
        house = HOUSES[house_idx]
        return {
            "houseId": house["id"],
            "houseName": house["name"],
            "vector": house["vector"],
            "westernSign": western,
            "easternSign": eastern,
            "siderealOffsetDeg": round(offset, 4),
        }
