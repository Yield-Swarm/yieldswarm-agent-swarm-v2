"""Mutation-driven charting swarm engine."""

from __future__ import annotations

import random
import statistics
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, List

from agents.system.constants import (
    HEARTBEAT_SECONDS,
    METAL_SKINS,
    TOTAL_CHARTING_AGENTS,
)
from agents.system.deity_manifests import ensure_deity_manifests, load_deity_manifests
from agents.system.zk_archive import ZKArchiveLedger


@dataclass
class AgentState:
    agent_id: str
    deity_manifest_id: str
    metal_skin: str
    generation: int = 0
    mutation_count: int = 0
    heartbeat_interval_seconds: int = HEARTBEAT_SECONDS
    last_heartbeat_at: int = field(default_factory=lambda: int(time.time()))
    performance_score: float = 0.0
    signal_precision: float = 0.5
    pnl_bps: float = 0.0
    active: bool = True

    def to_public(self) -> Dict[str, object]:
        payload = asdict(self)
        payload["heartbeat_age_seconds"] = int(time.time()) - self.last_heartbeat_at
        return payload


class MutatedChartingEngine:
    """Manages 10,080 charting agents with mutation and archival."""

    def __init__(self, root_dir: Path | str):
        self.root_dir = Path(root_dir)
        ensure_deity_manifests(self.root_dir)
        self.deity_manifests = load_deity_manifests(self.root_dir)
        self.agents: Dict[str, AgentState] = {}
        self.history: Dict[str, List[float]] = {}
        archive_path = self.root_dir / "system" / "archive" / "zk-archive.jsonl"
        self.archive = ZKArchiveLedger(archive_path)
        self.spawn_agents(TOTAL_CHARTING_AGENTS)

    def spawn_agents(self, count: int) -> None:
        deity_ids = sorted(self.deity_manifests.keys())
        for idx in range(1, count + 1):
            agent_id = f"chart-agent-{idx:05d}"
            if agent_id in self.agents:
                continue
            deity_id = deity_ids[(idx - 1) % len(deity_ids)]
            skin = METAL_SKINS[(idx - 1) % len(METAL_SKINS)]
            self.agents[agent_id] = AgentState(
                agent_id=agent_id,
                deity_manifest_id=deity_id,
                metal_skin=skin,
            )
            self.history[agent_id] = []

    def heartbeat(self, agent_id: str, at_time: int | None = None) -> AgentState:
        agent = self.agents[agent_id]
        agent.last_heartbeat_at = at_time or int(time.time())
        agent.active = True
        return agent

    def heartbeat_cycle(self, now: int | None = None) -> Dict[str, int]:
        current_time = now or int(time.time())
        active = 0
        stale = 0
        for agent in self.agents.values():
            if current_time - agent.last_heartbeat_at <= agent.heartbeat_interval_seconds:
                agent.active = True
                active += 1
            else:
                agent.active = False
                stale += 1
        return {"active": active, "stale": stale}

    def report_performance(
        self, agent_id: str, arena_score: float, signal_precision: float, pnl_bps: float
    ) -> Dict[str, object]:
        agent = self.agents[agent_id]
        bounded_precision = max(0.0, min(signal_precision, 1.0))
        normalized_pnl = max(-500.0, min(pnl_bps, 500.0)) / 500.0
        performance = (0.5 * arena_score) + (0.35 * bounded_precision * 100.0) + (
            0.15 * normalized_pnl * 100.0
        )
        agent.performance_score = round(performance, 4)
        agent.signal_precision = round(bounded_precision, 4)
        agent.pnl_bps = round(pnl_bps, 4)
        self.history[agent_id].append(agent.performance_score)
        if len(self.history[agent_id]) > 30:
            self.history[agent_id] = self.history[agent_id][-30:]
        self.heartbeat(agent_id)
        return agent.to_public()

    def _mutate(self, agent: AgentState) -> None:
        seed = f"{agent.agent_id}:{agent.mutation_count}:{agent.performance_score}"
        rng = random.Random(seed)
        skin_index = METAL_SKINS.index(agent.metal_skin)
        step = -1 if rng.random() < 0.5 else 1
        next_index = (skin_index + step) % len(METAL_SKINS)
        agent.metal_skin = METAL_SKINS[next_index]
        agent.mutation_count += 1
        agent.generation += 1

    def mutate_bottom_performers(self, ratio: float = 0.1, batch_size: int = 256) -> Dict[str, object]:
        ratio = max(0.01, min(ratio, 0.95))
        ranked = sorted(self.agents.values(), key=lambda item: item.performance_score)
        count = max(1, int(len(ranked) * ratio))
        candidates = ranked[:count][:batch_size]
        for agent in candidates:
            self._mutate(agent)
        return {
            "mutated_agents": len(candidates),
            "ratio": ratio,
            "batch_size": batch_size,
            "mean_pre_mutation_score": round(
                statistics.fmean([a.performance_score for a in candidates]), 4
            )
            if candidates
            else 0.0,
        }

    def leaderboard(self, limit: int = 100) -> List[Dict[str, object]]:
        limit = max(1, min(limit, len(self.agents)))
        ranked = sorted(
            self.agents.values(),
            key=lambda item: (
                item.performance_score,
                -item.mutation_count,
                item.last_heartbeat_at,
            ),
            reverse=True,
        )
        return [entry.to_public() for entry in ranked[:limit]]

    def get_agent(self, agent_id: str) -> Dict[str, object]:
        return self.agents[agent_id].to_public()

    def snapshot(self, note: str = "") -> Dict[str, object]:
        heartbeat_state = self.heartbeat_cycle()
        top_agents = self.leaderboard(limit=10)
        snapshot = {
            "note": note,
            "agent_count": len(self.agents),
            "heartbeat": heartbeat_state,
            "top_agents": top_agents,
        }
        return snapshot

    def archive_snapshot(self, note: str = "") -> Dict[str, object]:
        snapshot = self.snapshot(note=note)
        return self.archive.archive(snapshot, tags=("arena", "leaderboard", "mutation"))
