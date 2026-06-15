"""Self-healing Akash leases.

The fleet is hostile: providers fail, leases run out of AKT credits, and
revenue silently degrades. This subsystem is the autonomic nervous system of
the sovereign core. Every tick it:

* **Tops up** leases whose credit runway dips below the genome-aware buffer,
  funding them from the treasury (so healing has a real cost).
* **Migrates** degraded workers to a fresh provider, preserving the GPU class
  and the driving agent.
* **Resurrects** outright-failed leases by redeploying an equivalent worker.
* **Culls** chronically unprofitable workers so capital is not bled.

It returns the dollar cost of all healing actions so the core loop can debit
the treasury and the dashboard can show what reliability is costing.
"""

from __future__ import annotations

from typing import List

from core import HOURS_PER_TICK
from core.akash_feed import AkashFeed
from core.state import Event, SovereignState

# Below this many days of prepaid runway, refill the lease.
MIN_RUNWAY_DAYS = 6.0
# Days of runway a top-up / fresh lease is funded with.
REFILL_RUNWAY_DAYS = 24.0
# Re-provisioning a lease costs real cash (image pull, escrow, data egress).
REDEPLOY_FEE_USD = 25.0
MIGRATE_FEE_USD = 10.0
# Workers that stay net-negative this long get retired.
UNPROFITABLE_PATIENCE = 8


def _opex_per_tick(worker) -> float:
    return worker.hourly_cost_usd * HOURS_PER_TICK


def _runway_days(worker) -> float:
    opex = _opex_per_tick(worker)
    if opex <= 0:
        return float("inf")
    return worker.credits_usd / opex


def _fund_credits(state: SovereignState, worker, days: float) -> float:
    """Move cash from the vault into a lease's prepaid AKT credits.

    Net-worth neutral (cash -> prepaid asset). Returns the amount funded,
    bounded by available vault cash.
    """
    target = _opex_per_tick(worker) * days
    needed = max(0.0, target - worker.credits_usd)
    funded = min(needed, max(0.0, state.vault_usd))
    worker.credits_usd += funded
    state.vault_usd -= funded
    return funded


def step(state: SovereignState, feed: AkashFeed) -> List[Event]:
    events: List[Event] = []
    fees = 0.0

    # Snapshot list because we may append/remove workers while iterating.
    for w in list(state.workers):

        # 1) Resurrect hard-failed leases via redeploy on a new provider.
        #    The old lease's remaining credits are lost — that is the real
        #    dollar cost of a provider failure.
        if w.status == "failed":
            replacement = feed.provision(gpu_model=w.gpu_model, credits_usd=0.0)
            replacement.agent_id = w.agent_id
            replacement.hourly_revenue_usd = w.hourly_revenue_usd  # carry tuning
            old_provider, lost = w.provider, w.credits_usd
            state.workers.remove(w)
            state.workers.append(replacement)
            _fund_credits(state, replacement, REFILL_RUNWAY_DAYS)
            state.vault_usd = max(0.0, state.vault_usd - REDEPLOY_FEE_USD)
            fees += REDEPLOY_FEE_USD
            events.append(Event(
                state.tick, "healing", "redeploy",
                f"lease {w.dseq} on {old_provider} failed (lost ${lost:,.0f} "
                f"credits) -> redeployed {replacement.gpu_model} as "
                f"{replacement.dseq} on {replacement.provider}",
                impact_usd=-(REDEPLOY_FEE_USD + lost),
            ))
            continue

        # 2) Migrate degraded providers (keep agent + GPU class + credits).
        if w.status == "degraded":
            target = feed.provision(gpu_model=w.gpu_model, credits_usd=w.credits_usd)
            target.agent_id = w.agent_id
            target.hourly_revenue_usd = w.hourly_revenue_usd
            state.workers.remove(w)
            state.workers.append(target)
            state.vault_usd = max(0.0, state.vault_usd - MIGRATE_FEE_USD)
            fees += MIGRATE_FEE_USD
            events.append(Event(
                state.tick, "healing", "migrate",
                f"migrated degraded {w.dseq} ({w.health:.2f} health) -> "
                f"{target.dseq} on {target.provider}",
                impact_usd=-MIGRATE_FEE_USD,
            ))
            continue

        # 3) Top up leases that are about to run dry (cash -> prepaid credits).
        if _runway_days(w) < MIN_RUNWAY_DAYS:
            funded = _fund_credits(state, w, REFILL_RUNWAY_DAYS)
            if funded > 0:
                events.append(Event(
                    state.tick, "healing", "topup",
                    f"topped up lease {w.dseq} (+${funded:,.0f} AKT, runway "
                    f"now {_runway_days(w):.0f}d)",
                ))

        # 4) Retire chronically unprofitable workers.
        if w.roi < -0.05:
            w.unprofitable_ticks += 1
        else:
            w.unprofitable_ticks = 0
        if w.unprofitable_ticks > UNPROFITABLE_PATIENCE:
            state.workers.remove(w)
            events.append(Event(
                state.tick, "healing", "retire",
                f"retired chronically unprofitable lease {w.dseq} "
                f"(roi {w.roi:.2%})",
            ))

    for e in events:
        state.log(e)
    return events
