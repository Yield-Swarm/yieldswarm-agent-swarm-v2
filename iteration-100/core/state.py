"""Shared state, telemetry, and persistence for the sovereign core loop.

The whole system is a single evolving :class:`SovereignState` value. Each
subsystem (mutation, healing, treasury, marketplace) reads the state, returns
a list of :class:`Event` actions describing what it changed, and the core loop
folds those back in. The state is JSON-serialisable so the monitoring
dashboard can read it directly from ``state.json``.
"""

from __future__ import annotations

import dataclasses
import json
import os
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from . import VAULT_TARGET_USD


# --------------------------------------------------------------------------- #
# Domain models
# --------------------------------------------------------------------------- #


@dataclass
class AkashWorker:
    """A leased compute unit running on the Akash Network."""

    dseq: str                       # deployment sequence id (lease handle)
    provider: str                   # akash provider address / moniker
    gpu_model: str                  # e.g. "H100", "RTX4090", "A100"
    hourly_cost_usd: float          # what the lease costs us per hour
    hourly_revenue_usd: float       # mining / inference revenue per hour
    uptime: float                   # rolling availability 0..1
    health: float                   # provider-reported health 0..1
    credits_usd: float              # remaining AKT credits on the lease
    agent_id: Optional[str] = None  # agent currently driving this worker
    status: str = "active"          # active | degraded | failed | healing
    age_ticks: int = 0
    unprofitable_ticks: int = 0     # consecutive ticks net-negative

    @property
    def roi(self) -> float:
        """Profit margin per hour, normalised by cost (can be negative)."""
        if self.hourly_cost_usd <= 0:
            return 0.0
        return (self.hourly_revenue_usd - self.hourly_cost_usd) / self.hourly_cost_usd

    @property
    def net_hourly_usd(self) -> float:
        return (self.hourly_revenue_usd - self.hourly_cost_usd) * self.uptime


@dataclass
class Agent:
    """An autonomous trading/optimisation agent with an evolvable genome.

    The genome is the set of knobs the mutation engine tunes. Fitness is
    derived from the realised ROI of the Akash workers the agent drives.
    """

    agent_id: str
    genome: Dict[str, float]
    fitness: float = 0.0
    generation: int = 0
    lineage: str = "genesis"
    assigned_workers: List[str] = field(default_factory=list)
    realized_pnl_usd: float = 0.0


@dataclass
class YieldStrategy:
    """A treasury allocation venue (DeFi vault, DePIN stake, LP, etc.)."""

    name: str
    allocation_usd: float
    apy: float                      # current annualised yield 0..1
    risk: float                     # 0 (stable) .. 1 (degen)
    liquid: bool = True             # can we rebalance out cheaply?
    baseline_apy: float = 0.0       # long-run mean the APY reverts toward


@dataclass
class MarketOrder:
    """A demand-side order routed by the Great Delta Grid."""

    order_id: str
    kind: str                       # "compute" | "talent"
    spec: str                       # gpu model or skill tag
    budget_usd: float               # what the buyer will pay
    duration_h: float
    status: str = "open"            # open | matched | settled | unfilled
    matched_to: Optional[str] = None
    fee_usd: float = 0.0


@dataclass
class Event:
    """An action taken by a subsystem during a tick (for the activity feed)."""

    tick: int
    subsystem: str
    kind: str
    detail: str
    impact_usd: float = 0.0


@dataclass
class SovereignState:
    tick: int = 0
    started_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)

    vault_usd: float = 0.0
    vault_target_usd: float = VAULT_TARGET_USD
    target_apy: float = 0.30        # sovereign mandate: hold >= 30% blended APY

    workers: List[AkashWorker] = field(default_factory=list)
    agents: List[Agent] = field(default_factory=list)
    strategies: List[YieldStrategy] = field(default_factory=list)
    orders: List[MarketOrder] = field(default_factory=list)

    events: List[Event] = field(default_factory=list)
    history: List[Dict[str, Any]] = field(default_factory=list)

    # ---- derived metrics --------------------------------------------------- #

    @property
    def treasury_total_usd(self) -> float:
        return sum(s.allocation_usd for s in self.strategies)

    @property
    def blended_apy(self) -> float:
        total = self.treasury_total_usd
        if total <= 0:
            return 0.0
        return sum(s.allocation_usd * s.apy for s in self.strategies) / total

    @property
    def fleet_credits_usd(self) -> float:
        """Prepaid AKT lease credits are a balance-sheet asset, not a sunk cost."""
        return sum(w.credits_usd for w in self.workers)

    @property
    def net_worth_usd(self) -> float:
        return self.vault_usd + self.treasury_total_usd + self.fleet_credits_usd

    @property
    def progress(self) -> float:
        return min(1.0, self.net_worth_usd / self.vault_target_usd)

    @property
    def fleet_net_hourly_usd(self) -> float:
        return sum(w.net_hourly_usd for w in self.workers if w.status == "active")

    @property
    def healthy_worker_ratio(self) -> float:
        if not self.workers:
            return 0.0
        active = sum(1 for w in self.workers if w.status == "active")
        return active / len(self.workers)

    # ---- helpers ----------------------------------------------------------- #

    def worker(self, dseq: str) -> Optional[AkashWorker]:
        return next((w for w in self.workers if w.dseq == dseq), None)

    def agent(self, agent_id: str) -> Optional[Agent]:
        return next((a for a in self.agents if a.agent_id == agent_id), None)

    def log(self, event: Event) -> None:
        self.events.append(event)
        # keep the activity feed bounded
        if len(self.events) > 400:
            self.events = self.events[-400:]

    # ---- serialisation ----------------------------------------------------- #

    def fleet_by_gpu(self) -> List[Dict[str, Any]]:
        """Aggregate the (potentially huge) fleet by GPU class for the dashboard."""
        agg: Dict[str, Dict[str, float]] = {}
        for w in self.workers:
            a = agg.setdefault(w.gpu_model, {
                "gpu_model": w.gpu_model, "count": 0, "active": 0,
                "net_hourly_usd": 0.0, "roi_sum": 0.0, "credits_usd": 0.0,
            })
            a["count"] += 1
            a["active"] += 1 if w.status == "active" else 0
            a["net_hourly_usd"] += w.net_hourly_usd
            a["roi_sum"] += w.roi
            a["credits_usd"] += w.credits_usd
        out = []
        for a in agg.values():
            cnt = a["count"] or 1
            out.append({
                "gpu_model": a["gpu_model"],
                "count": a["count"],
                "active": a["active"],
                "net_hourly_usd": round(a["net_hourly_usd"], 2),
                "avg_roi": round(a["roi_sum"] / cnt, 4),
                "credits_usd": round(a["credits_usd"], 2),
            })
        return sorted(out, key=lambda x: x["net_hourly_usd"], reverse=True)

    def snapshot(self, worker_sample: int = 48) -> Dict[str, Any]:
        """Compact, dashboard-friendly view of the current state."""
        top_agents = sorted(self.agents, key=lambda a: a.fitness, reverse=True)
        return {
            "iteration": 100,
            "tick": self.tick,
            "updated_at": self.updated_at,
            "vault_usd": round(self.vault_usd, 2),
            "treasury_usd": round(self.treasury_total_usd, 2),
            "fleet_credits_usd": round(self.fleet_credits_usd, 2),
            "net_worth_usd": round(self.net_worth_usd, 2),
            "vault_target_usd": self.vault_target_usd,
            "progress": round(self.progress, 6),
            "target_apy": self.target_apy,
            "blended_apy": round(self.blended_apy, 4),
            "fleet_net_hourly_usd": round(self.fleet_net_hourly_usd, 2),
            "healthy_worker_ratio": round(self.healthy_worker_ratio, 4),
            "counts": {
                "workers": len(self.workers),
                "active_workers": sum(1 for w in self.workers if w.status == "active"),
                "degraded_workers": sum(1 for w in self.workers if w.status == "degraded"),
                "agents": len(self.agents),
                "strategies": len(self.strategies),
                "open_orders": sum(1 for o in self.orders if o.status == "open"),
                "settled_orders": sum(1 for o in self.orders if o.status == "settled"),
            },
            "fleet_by_gpu": self.fleet_by_gpu(),
            "workers": [
                dataclasses.asdict(w) | {"roi": round(w.roi, 4)}
                for w in self.workers[:worker_sample]
            ],
            "agents": [
                {
                    "agent_id": a.agent_id,
                    "genome": a.genome,
                    "fitness": round(a.fitness, 5),
                    "generation": a.generation,
                    "lineage": a.lineage,
                    "assigned_workers": len(a.assigned_workers),
                    "realized_pnl_usd": round(a.realized_pnl_usd, 2),
                }
                for a in top_agents[:24]
            ],
            "strategies": [dataclasses.asdict(s) for s in self.strategies],
            "orders": [dataclasses.asdict(o) for o in self.orders[-40:]],
            "events": [dataclasses.asdict(e) for e in self.events[-60:]],
            "history": self.history[-600:],
        }

    def to_json(self) -> str:
        return json.dumps(self.snapshot(), indent=2)


def persist(state: SovereignState, path: str) -> None:
    """Atomically write the dashboard snapshot to ``path``."""
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(state.to_json())
    os.replace(tmp, path)


def load(path: str) -> Optional[SovereignState]:
    """Restore a :class:`SovereignState` from a persisted dashboard snapshot."""
    path = os.path.abspath(path)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            snap = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None
    return from_snapshot(snap)


def from_snapshot(snap: Dict[str, Any]) -> SovereignState:
    """Rebuild runtime state from a dashboard snapshot dict."""
    workers = []
    for row in snap.get("workers", []):
        data = {k: v for k, v in row.items() if k != "roi"}
        workers.append(AkashWorker(**data))

    agents = []
    for row in snap.get("agents", []):
        assigned = row.get("assigned_workers", [])
        if isinstance(assigned, int):
            assigned = []
        agents.append(Agent(
            agent_id=row["agent_id"],
            genome=row.get("genome") or {},
            fitness=float(row.get("fitness", 0.0)),
            generation=int(row.get("generation", 0)),
            lineage=row.get("lineage", "genesis"),
            assigned_workers=list(assigned),
            realized_pnl_usd=float(row.get("realized_pnl_usd", 0.0)),
        ))

    strategies = [YieldStrategy(**row) for row in snap.get("strategies", [])]
    orders = [MarketOrder(**row) for row in snap.get("orders", [])]
    events = [Event(**row) for row in snap.get("events", [])]

    return SovereignState(
        tick=int(snap.get("tick", 0)),
        started_at=float(snap.get("started_at", snap.get("updated_at", time.time()))),
        updated_at=float(snap.get("updated_at", time.time())),
        vault_usd=float(snap.get("vault_usd", 0.0)),
        vault_target_usd=float(snap.get("vault_target_usd", VAULT_TARGET_USD)),
        target_apy=float(snap.get("target_apy", 0.30)),
        workers=workers,
        agents=agents,
        strategies=strategies,
        orders=orders,
        events=events,
        history=list(snap.get("history", [])),
    )
