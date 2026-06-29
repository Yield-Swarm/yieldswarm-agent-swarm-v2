"""RuneScape-style skill progression — 4 core skills."""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any


SKILLS = (
    "compute_harvesting",
    "algorithmic_splicing",
    "swarm_telemetry",
    "liquidity_fortification",
)

XP_TABLE = {level: int(83 * (level ** 2.5)) for level in range(1, 100)}


@dataclass
class PlayerSkills:
    player_id: str
    skills: dict[str, dict[str, Any]] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.skills:
            self.skills = {s: {"level": 1, "xp": 0.0, "masteryTier": "bronze"} for s in SKILLS}

    def level_for_xp(self, xp: float) -> int:
        level = 1
        for lv in range(1, 99):
            if xp >= XP_TABLE.get(lv, 0):
                level = lv
        return min(level, 99)

    def mastery_tier(self, level: int) -> str:
        if level >= 90:
            return "platinum"
        if level >= 70:
            return "gold"
        if level >= 40:
            return "silver"
        return "bronze"

    def apply_xp(self, skill: str, xp_delta: float, source: str) -> dict[str, Any]:
        if skill not in self.skills:
            self.skills[skill] = {"level": 1, "xp": 0.0, "masteryTier": "bronze"}
        entry = self.skills[skill]
        old_level = entry["level"]
        entry["xp"] = round(float(entry["xp"]) + xp_delta, 4)
        new_level = self.level_for_xp(entry["xp"])
        entry["level"] = new_level
        entry["masteryTier"] = self.mastery_tier(new_level)
        leveled_up = new_level > old_level
        return {
            "playerId": self.player_id,
            "skill": skill,
            "xpDelta": xp_delta,
            "source": source,
            "newLevel": new_level,
            "leveledUp": leveled_up,
            "masteryTier": entry["masteryTier"],
        }


class SkillProgressionEngine:
    """Maps physical/mesh events to skill XP."""

    EVENT_SKILL_MAP = {
        "power_accel": ("compute_harvesting", 15.0),
        "precision_braking": ("swarm_telemetry", 12.0),
        "cruise_explore": ("algorithmic_splicing", 8.0),
        "data_rift": ("liquidity_fortification", 20.0),
        "pool_switch": ("compute_harvesting", 10.0),
        "runic_referral": ("liquidity_fortification", 25.0),
    }

    def __init__(self) -> None:
        self._players: dict[str, PlayerSkills] = {}

    def get_player(self, player_id: str) -> PlayerSkills:
        if player_id not in self._players:
            self._players[player_id] = PlayerSkills(player_id=player_id)
        return self._players[player_id]

    def ingest_event(self, player_id: str, event_type: str, xp_override: float | None = None) -> dict[str, Any]:
        mapping = self.EVENT_SKILL_MAP.get(event_type, ("swarm_telemetry", 5.0))
        skill, default_xp = mapping
        xp = xp_override if xp_override is not None else default_xp
        player = self.get_player(player_id)
        result = player.apply_xp(skill, xp, event_type)
        result["skills"] = player.skills
        return result
