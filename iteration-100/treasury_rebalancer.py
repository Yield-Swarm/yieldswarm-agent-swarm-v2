"""Dynamic treasury rebalancing when blended APY drops below target.

The sovereign mandate is to keep the blended treasury APY at or above
``state.target_apy`` (default 30%). Markets move, so each tick:

1. APYs drift (DeFi rates compress, DePIN rewards spike, etc.).
2. The treasury accrues one tick of yield into the operating vault.
3. If the *blended* APY falls below target, capital is pulled out of the
   lowest-yielding liquid venues and redeployed into the highest-yielding ones
   until the target is restored or we run out of liquid headroom.

This is a greedy, risk-aware rebalance: it never moves illiquid capital and it
respects a per-venue risk ceiling so the chase for yield does not nuke the
vault. Mining/marketplace inflows are added as fresh allocation, compounding.
"""

from __future__ import annotations

import random
from typing import List

from core import DAYS_PER_YEAR
from core.state import Event, SovereignState, YieldStrategy

_rng = random.Random(424242)
# Don't pour more than this fraction of treasury into a single risky venue.
MAX_RISK_CONCENTRATION = 0.45


def default_strategies(seed_capital: float) -> List[YieldStrategy]:
    """A diversified starting book across the YieldSwarm venue universe."""
    book = [
        YieldStrategy("AkashStake-DePIN",   0.22, 0.41, 0.55, True),
        YieldStrategy("HelixChain-LP",      0.20, 0.36, 0.62, True),
        YieldStrategy("Chainlink-Vault",    0.18, 0.22, 0.20, True),
        YieldStrategy("Bittensor-Subnet",   0.15, 0.48, 0.78, True),
        YieldStrategy("Solana-JLP",         0.15, 0.28, 0.45, True),
        YieldStrategy("USDC-TBill",         0.10, 0.05, 0.02, True),
    ]
    for s in book:
        s.allocation_usd = round(seed_capital * s.allocation_usd, 2)
        s.baseline_apy = s.apy
    return book


def _drift_apys(state: SovereignState) -> None:
    """Ornstein-Uhlenbeck-style mean reversion toward each venue baseline.

    Yields wander (so the rebalancer has work to do) but pull back toward a
    sustainable long-run mean instead of random-walking to zero.
    """
    for s in state.strategies:
        vol = 0.004 + 0.012 * s.risk          # risky venues are more volatile
        reversion = 0.05 * (s.baseline_apy - s.apy)
        s.apy = max(0.0, s.apy + reversion + _rng.gauss(0, vol))


def accrue_yield(state: SovereignState) -> float:
    """Compound one hour of yield from every venue back into the treasury."""
    earned = 0.0
    for s in state.strategies:
        gain = s.allocation_usd * (s.apy / DAYS_PER_YEAR)
        s.allocation_usd += gain
        earned += gain
    return earned


def add_capital(state: SovereignState, amount_usd: float) -> None:
    """Route external inflow (mining, fees) into the best risk-adjusted venue."""
    if amount_usd <= 0 or not state.strategies:
        return
    ranked = sorted(
        state.strategies,
        key=lambda s: s.apy / (1.0 + s.risk),
        reverse=True,
    )
    ranked[0].allocation_usd += amount_usd


def rebalance(state: SovereignState) -> List[Event]:
    events: List[Event] = []
    if not state.strategies:
        return events

    if state.blended_apy >= state.target_apy:
        return events

    total = state.treasury_total_usd
    # Sources: liquid, low-yield venues. Sinks: high risk-adjusted-yield venues.
    sources = sorted(
        (s for s in state.strategies if s.liquid),
        key=lambda s: s.apy,
    )
    sinks = [s for s in sorted(state.strategies, key=lambda s: s.apy, reverse=True)]
    if not sinks:
        return events

    cap = total * MAX_RISK_CONCENTRATION
    moved_total = 0.0
    last_sink = sinks[0]

    def best_sink_with_headroom(min_apy: float):
        for cand in sinks:
            if cand.apy > min_apy and (cap - cand.allocation_usd) > 1.0:
                return cand
        return None

    # Move capital in tranches from the worst liquid venues into the best
    # venue that still has risk-concentration headroom.
    for src in sources:
        if state.blended_apy >= state.target_apy:
            break
        sink = best_sink_with_headroom(src.apy)
        if sink is None or sink is src:
            continue
        headroom = max(0.0, cap - sink.allocation_usd)
        move = min(src.allocation_usd * 0.6, headroom)
        if move < 1.0:
            continue
        src.allocation_usd -= move
        sink.allocation_usd += move
        moved_total += move
        last_sink = sink

    if moved_total > 0:
        events.append(Event(
            state.tick, "treasury", "rebalance",
            f"blended APY {state.blended_apy:.1%} < target "
            f"{state.target_apy:.0%}: moved ${moved_total:,.0f} into "
            f"{last_sink.name} ({last_sink.apy:.0%} APY)",
        ))
        for e in events:
            state.log(e)
    return events


def step(state: SovereignState, inflow_usd: float = 0.0) -> List[Event]:
    """Drift -> accrue -> absorb deposits -> rebalance to defend target APY."""
    _drift_apys(state)
    earned = accrue_yield(state)
    add_capital(state, inflow_usd)
    events = rebalance(state)
    if earned > 0 and state.tick % 5 == 0:
        state.log(Event(
            state.tick, "treasury", "yield",
            f"accrued ${earned:,.2f}/h yield @ {state.blended_apy:.1%} blended APY",
            impact_usd=earned,
        ))
    return events
