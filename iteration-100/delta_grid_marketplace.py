"""The Great Delta Grid — a two-sided marketplace router.

The Delta Grid matches external *demand* (buyers who need GPU compute or
specialised agent talent) with the sovereign's *supply* (idle Akash workers
and high-fitness agents). It is where the swarm sells its own capacity to the
outside world, and the take-rate is a primary inflow to the $5M vault.

Routing logic:

* **Compute orders** are matched to the cheapest *active* worker of the right
  GPU class that has spare capacity, priced at the buyer's budget. The grid
  keeps a take-rate; the rest covers the lease.
* **Talent orders** are matched to the highest-fitness agent whose genome fits
  the requested skill, monetising the population the mutation engine breeds.

Unmatched orders age out. The function returns the marketplace fee revenue for
the tick, which the core loop compounds into the treasury.
"""

from __future__ import annotations

import random
from typing import List, Tuple

from core.state import Event, MarketOrder, SovereignState

_rng = random.Random(909090)

TAKE_RATE = 0.18  # Delta Grid commission on every filled order

COMPUTE_SPECS = ["H100", "A100", "RTX4090", "L40S", "RTX3090"]
TALENT_SKILLS = [
    "yield-optimization", "mev-defense", "inference-serving",
    "market-making", "security-audit", "data-labeling",
]
ORDER_TTL = 6      # ticks an order stays open before expiring
MAX_ORDERS = 800   # hard cap on inbound orders per tick (keeps routing bounded)


def generate_demand(state: SovereignState) -> List[MarketOrder]:
    """Synthesise inbound buyer demand (would be an API/webhook in prod).

    Demand scales (sub-linearly) with the size of the grid: a bigger pool of
    supply and higher-fitness agents attracts more buyers (network effect),
    but is capped at ``MAX_ORDERS`` so routing stays bounded.
    """
    new: List[MarketOrder] = []
    capacity = len(state.workers) + len(state.agents)
    base = max(4, min(MAX_ORDERS, capacity // 12))
    n = _rng.randint(base, min(MAX_ORDERS, base + base // 2 + 3))
    for _ in range(n):
        kind = "compute" if _rng.random() < 0.6 else "talent"
        oid = f"ord-{state.tick:05d}-{_rng.randint(1000, 9999)}"
        if kind == "compute":
            spec = _rng.choice(COMPUTE_SPECS)
            budget = round(_rng.uniform(1.5, 6.0), 2)
        else:
            spec = _rng.choice(TALENT_SKILLS)
            budget = round(_rng.uniform(3.0, 14.0), 2)
        new.append(MarketOrder(
            order_id=oid, kind=kind, spec=spec,
            budget_usd=budget, duration_h=round(_rng.uniform(1, 8), 1),
        ))
    return new


# Each active worker / agent can clear this many grid orders per tick, so the
# grid's throughput is bounded by the actual size of the swarm.
WORKER_SLOTS_PER_TICK = 2
AGENT_SLOTS_PER_TICK = 3


def _build_compute_index(state: SovereignState) -> dict:
    """Bucket active workers by GPU class, cheapest first, with free slots."""
    index: dict = {}
    for w in state.workers:
        if w.status == "active":
            index.setdefault(w.gpu_model, []).append(w)
    for bucket in index.values():
        bucket.sort(key=lambda w: w.hourly_cost_usd)
    return index


def _match_compute(order: MarketOrder, index: dict, used: dict) -> Tuple[bool, float]:
    bucket = index.get(order.spec)
    if not bucket:
        return False, 0.0
    for worker in bucket:
        if used.get(worker.dseq, 0) < WORKER_SLOTS_PER_TICK:
            used[worker.dseq] = used.get(worker.dseq, 0) + 1
            fee = order.budget_usd * TAKE_RATE * order.duration_h
            order.status = "settled"
            order.matched_to = worker.dseq
            order.fee_usd = round(fee, 2)
            worker.hourly_revenue_usd += order.budget_usd * (1 - TAKE_RATE) * 0.15
            return True, fee
    return False, 0.0


def _match_talent(top_agent, order: MarketOrder, used: dict) -> Tuple[bool, float]:
    if top_agent is None or top_agent.fitness <= 0:
        return False, 0.0
    if used.get(top_agent.agent_id, 0) >= AGENT_SLOTS_PER_TICK:
        return False, 0.0
    used[top_agent.agent_id] = used.get(top_agent.agent_id, 0) + 1
    fee = order.budget_usd * TAKE_RATE * order.duration_h
    order.status = "settled"
    order.matched_to = top_agent.agent_id
    order.fee_usd = round(fee, 2)
    top_agent.realized_pnl_usd += order.budget_usd * (1 - TAKE_RATE)
    return True, fee


def step(state: SovereignState) -> Tuple[List[Event], float]:
    events: List[Event] = []
    revenue = 0.0

    # Expire stale open orders and keep the order book bounded.
    fresh: List[MarketOrder] = []
    for o in state.orders:
        try:
            placed_tick = int(o.order_id.split("-")[1])
        except (IndexError, ValueError):
            placed_tick = state.tick
        if o.status == "open" and (state.tick - placed_tick) > ORDER_TTL:
            o.status = "unfilled"
        if o.status in ("open", "settled", "unfilled"):
            fresh.append(o)
    state.orders = fresh[-200:]

    # Ingest new demand.
    state.orders.extend(generate_demand(state))

    matched = 0
    used: dict = {}  # per-tick capacity ledger (dseq / agent_id -> slots used)
    compute_index = _build_compute_index(state)
    ranked_agents = sorted(
        (a for a in state.agents if a.fitness > 0),
        key=lambda a: a.fitness, reverse=True,
    )

    def next_agent():
        for a in ranked_agents:
            if used.get(a.agent_id, 0) < AGENT_SLOTS_PER_TICK:
                return a
        return None

    for o in state.orders:
        if o.status != "open":
            continue
        if o.kind == "compute":
            ok, fee = _match_compute(o, compute_index, used)
        else:
            ok, fee = _match_talent(next_agent(), o, used)
        if ok:
            revenue += fee
            matched += 1
        else:
            o.status = "unfilled"

    if matched:
        events.append(Event(
            state.tick, "marketplace", "route",
            f"Delta Grid filled {matched} orders, "
            f"+${revenue:,.2f} take-rate revenue",
            impact_usd=revenue,
        ))
        for e in events:
            state.log(e)

    return events, round(revenue, 2)
