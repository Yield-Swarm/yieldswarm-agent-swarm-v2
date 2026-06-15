"""Iteration 100 — the sovereign self-governed core loop.

This is the orchestrator. It owns the :class:`SovereignState` and, on every
tick, drives the four autonomous subsystems in dependency order:

    Akash telemetry  ->  agent mutation  ->  self-healing  ->
    Delta Grid marketplace  ->  treasury rebalancing  ->  reinvestment

The loop is *self-governed*: nothing here is hand-tuned per tick. Agents evolve
against real worker ROI, leases heal themselves, the treasury defends its APY
mandate, and surplus is recycled into more compute — all pulling toward the
single objective of a $5,000,000 vault.

Run it:

    python3 run.py --ticks 2000 --interval 0
"""

from __future__ import annotations

import os
import sys
import time
from dataclasses import dataclass
from typing import Optional

# Make the package importable whether run from repo root or this directory.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import agent_mutation
import delta_grid_marketplace as delta_grid
import self_healing_leases
import treasury_rebalancer
from core import VAULT_TARGET_USD
from core.akash_feed import AkashFeed
from core.state import Event, SovereignState, persist


@dataclass
class CoreConfig:
    seed_workers: int = 150
    seed_agents: int = 40
    seed_treasury_usd: float = 400_000.0
    seed_vault_usd: float = 40_000.0
    target_apy: float = 0.30
    state_path: str = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "dashboard", "state.json"
    )
    # Reinvest into new leases / treasury when the vault carries this surplus.
    reinvest_threshold_usd: float = 3_000.0
    lease_capex_usd: float = 400.0
    # Fraction of reinvested surplus that buys compute vs. compounding treasury.
    compute_reinvest_frac: float = 0.6
    max_fleet: int = 1_500


class SovereignCore:
    def __init__(self, config: Optional[CoreConfig] = None):
        self.cfg = config or CoreConfig()
        self.feed = AkashFeed()
        self.state = self._bootstrap()

    # ------------------------------------------------------------------ #

    def _bootstrap(self) -> SovereignState:
        s = SovereignState(
            vault_usd=self.cfg.seed_vault_usd,
            vault_target_usd=VAULT_TARGET_USD,
            target_apy=self.cfg.target_apy,
        )
        s.workers = self.feed.seed_fleet(self.cfg.seed_workers)
        s.agents = agent_mutation.spawn_population(self.cfg.seed_agents)
        s.strategies = treasury_rebalancer.default_strategies(self.cfg.seed_treasury_usd)
        agent_mutation.assign_workers(s)
        s.log(Event(0, "core", "boot",
                    f"Iteration 100 sovereign core online: "
                    f"{len(s.workers)} leases, {len(s.agents)} agents, "
                    f"${s.treasury_total_usd:,.0f} treasury, "
                    f"target ${s.vault_target_usd:,.0f}"))
        return s

    # ------------------------------------------------------------------ #

    def _reinvest(self) -> None:
        """Recycle vault surplus into compute + treasury (compounding capex).

        Two engines grow off the same surplus: new Akash leases (which lift
        fleet + marketplace revenue) and fresh treasury deposits (which lift
        compounding yield). The split is the sovereign's capital policy.
        """
        s = self.state
        surplus = s.vault_usd - self.cfg.reinvest_threshold_usd
        if surplus <= self.cfg.lease_capex_usd:
            return

        compute_budget = surplus * self.cfg.compute_reinvest_frac
        n = int(compute_budget // self.cfg.lease_capex_usd)
        n = max(0, min(n, self.cfg.max_fleet - len(s.workers)))
        spent_capex = 0.0
        for _ in range(n):
            w = self.feed.provision(credits_usd=self.cfg.lease_capex_usd)
            s.workers.append(w)
            spent_capex += self.cfg.lease_capex_usd
        s.vault_usd -= spent_capex

        # Sweep the remaining surplus into the treasury to compound at APY.
        deposit = max(0.0, (s.vault_usd - self.cfg.reinvest_threshold_usd))
        if deposit > 1.0:
            treasury_rebalancer.add_capital(s, deposit)
            s.vault_usd -= deposit

        if n or deposit > 1.0:
            s.log(Event(
                s.tick, "core", "reinvest",
                f"reinvested surplus: +{n} leases (fleet {len(s.workers)}), "
                f"+${deposit:,.0f} to treasury",
            ))

    def _record_history(self) -> None:
        s = self.state
        s.history.append({
            "tick": s.tick,
            "vault_usd": round(s.vault_usd, 2),
            "treasury_usd": round(s.treasury_total_usd, 2),
            "net_worth_usd": round(s.net_worth_usd, 2),
            "blended_apy": round(s.blended_apy, 4),
            "progress": round(s.progress, 6),
            "workers": len(s.workers),
            "active_workers": sum(1 for w in s.workers if w.status == "active"),
            "agents": len(s.agents),
            "fleet_net_hourly_usd": round(s.fleet_net_hourly_usd, 2),
            "best_fitness": round(max((a.fitness for a in s.agents), default=0.0), 4),
        })
        if len(s.history) > 5000:
            s.history = s.history[-5000:]

    # ------------------------------------------------------------------ #

    def tick(self) -> None:
        s = self.state
        s.tick += 1

        # 1) Pull real(istic) performance data off the Akash fleet. Gross
        #    lease revenue books into the vault; opex is consumed from prepaid
        #    credits inside the feed.
        feed_result = self.feed.refresh(s)
        s.vault_usd += feed_result["gross_revenue_usd"]

        # 2) Evolve the agent population against measured worker ROI.
        agent_mutation.step(s)

        # 3) Heal the fleet (redeploy/migrate/top-up failing leases).
        self_healing_leases.step(s, self.feed)

        # 4) Route the Great Delta Grid marketplace; fees are pure profit.
        _, market_revenue = delta_grid.step(s)
        s.vault_usd += market_revenue

        # 5) Treasury drifts, compounds its yield, and defends the APY mandate.
        treasury_rebalancer.step(s)

        # 7) Recycle surplus into more compute + treasury.
        self._reinvest()

        # 8) Persist for the dashboard.
        s.updated_at = time.time()
        self._record_history()
        persist(s, self.cfg.state_path)

    # ------------------------------------------------------------------ #

    def run(self, ticks: int, interval: float = 0.0, verbose: bool = True) -> SovereignState:
        for _ in range(ticks):
            self.tick()
            if verbose and self.state.tick % 25 == 0:
                self._print_status()
            if self.state.progress >= 1.0:
                if verbose:
                    print(f"\n>>> VAULT TARGET REACHED at tick {self.state.tick} "
                          f"(${self.state.net_worth_usd:,.0f})\n")
                break
            if interval:
                time.sleep(interval)
        return self.state

    def _print_status(self) -> None:
        s = self.state
        bar_len = 30
        filled = int(s.progress * bar_len)
        bar = "#" * filled + "-" * (bar_len - filled)
        print(
            f"tick {s.tick:>5} | [{bar}] {s.progress:6.2%} | "
            f"net ${s.net_worth_usd:>12,.0f} | vault ${s.vault_usd:>10,.0f} | "
            f"APY {s.blended_apy:5.1%} | leases {len(s.workers):>3} "
            f"({s.healthy_worker_ratio:4.0%} healthy) | "
            f"agents {len(s.agents):>3}"
        )
