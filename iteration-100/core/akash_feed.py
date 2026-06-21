"""Real-or-simulated performance feed for Akash workers.

In production this module shells out to ``akash query market lease list``
and reads lease endpoints from ``akash/state/leases.json`` (written by
``lease-manager.py --deploy``). When unavailable we fall back to simulation.
"""

from __future__ import annotations

import json
import os
import random
import subprocess
from typing import Dict, List, Optional

from . import HOURS_PER_TICK
from .state import AkashWorker, SovereignState

GPU_CATALOG = {
    #             cost/h   base rev/h
    "H100":     (2.80, 4.10),
    "A100":     (1.40, 2.05),
    "RTX4090":  (0.42, 0.66),
    "RTX3090":  (0.28, 0.40),
    "L40S":     (1.10, 1.62),
}

PROVIDERS = [
    "akash1prov-helix", "akash1prov-hydrogen", "akash1prov-cern",
    "akash1prov-eliza", "akash1prov-gensyn", "akash1prov-openclaw",
]


class AkashFeed:
    """Yields fresh worker telemetry every tick.

    Set ``AKASH_LIVE=1`` and provide ``AKASH_KEY_NAME`` to attempt real lease
    queries; otherwise the simulator is used. The simulator models provider
    drift, occasional lease failures, and revenue volatility so the
    self-healing and mutation systems have something real to react to.
    """

    def __init__(self, seed: Optional[int] = None):
        seed = seed if seed is not None else int(os.getenv("AKASH_FEED_SEED", "100"))
        self._rng = random.Random(seed)
        self._live = os.getenv("AKASH_LIVE", "0") == "1"
        self._dseq_counter = 1000
        self._lease_endpoints = self._load_lease_endpoints()

    def _load_lease_endpoints(self) -> Dict[str, str]:
        """Load miner/backend URLs from akash/state/leases.json."""
        path = os.getenv(
            "AKASH_LEASES_FILE",
            os.path.join(os.path.dirname(__file__), "..", "..", "akash", "state", "leases.json"),
        )
        try:
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, json.JSONDecodeError):
            return {}
        out: Dict[str, str] = {}
        for lease in data.get("leases", []):
            profile = lease.get("profile", lease.get("role", "worker"))
            url = lease.get("worker_url") or (lease.get("uris") or [None])[0]
            if url:
                out[str(profile)] = str(url)
        return out

    def lease_endpoints(self) -> Dict[str, str]:
        return dict(self._lease_endpoints)

    # ------------------------------------------------------------------ #
    # Provisioning
    # ------------------------------------------------------------------ #

    def provision(self, gpu_model: Optional[str] = None,
                  credits_usd: float = 200.0) -> AkashWorker:
        """Spin up a new lease (real attempt -> simulated fallback)."""
        model = gpu_model or self._rng.choice(list(GPU_CATALOG))
        # Prefer H100 when miner lease endpoint is configured
        if "miner" in self._lease_endpoints and model not in GPU_CATALOG:
            model = "H100"
        if "miner" in self._lease_endpoints and self._rng.random() < 0.35:
            model = "H100"
        cost, base_rev = GPU_CATALOG[model]
        self._dseq_counter += self._rng.randint(1, 7)
        provider = self._rng.choice(PROVIDERS)
        # revenue starts near break-even and is improved by agent tuning later
        rev = base_rev * self._rng.uniform(0.88, 1.18)
        return AkashWorker(
            dseq=str(self._dseq_counter),
            provider=provider,
            gpu_model=model,
            hourly_cost_usd=round(cost, 4),
            hourly_revenue_usd=round(rev, 4),
            uptime=round(self._rng.uniform(0.95, 0.999), 4),
            health=round(self._rng.uniform(0.9, 1.0), 4),
            credits_usd=credits_usd,
        )

    def seed_fleet(self, n: int) -> List[AkashWorker]:
        return [self.provision() for _ in range(n)]

    # ------------------------------------------------------------------ #
    # Per-tick telemetry refresh
    # ------------------------------------------------------------------ #

    def refresh(self, state: SovereignState) -> Dict[str, float]:
        """Advance every worker's telemetry by one tick (one operating day).

        Accounting (clean prepaid-opex model):
          * ``gross_revenue`` (revenue * uptime * hours) is returned and booked
            into the operating vault by the core loop.
          * lease opex (cost * hours) is consumed from the worker's prepaid AKT
            credits — credits are a balance-sheet asset, so this is the only
            place real cost leaves the system.
          * a worker that exhausts its credits is marked ``failed`` so the
            self-healer redeploys it.
        """
        if self._live:
            live = self._query_live_leases()
            if live:
                self._merge_live(state, live)

        gross_revenue = 0.0
        for w in state.workers:
            w.age_ticks += 1

            # Provider health drifts; the agent genome (set elsewhere) already
            # nudged revenue. Add organic volatility here.
            w.health = _clamp(w.health + self._rng.uniform(-0.03, 0.03), 0.0, 1.0)

            # Uptime wobble correlated with health.
            w.uptime = _clamp(
                w.uptime + self._rng.uniform(-0.02, 0.015) + (w.health - 0.95) * 0.05,
                0.0, 1.0,
            )

            # Revenue volatility (market price of compute / coin price).
            w.hourly_revenue_usd = max(
                0.0, w.hourly_revenue_usd * self._rng.uniform(0.97, 1.04),
            )

            # Rare catastrophic provider failure — the self-healer reacts.
            if w.status == "active" and self._rng.random() < 0.012:
                w.status = "failed"
                w.uptime = 0.0
                w.health = 0.0
            elif w.status == "active" and w.health < 0.55:
                w.status = "degraded"

            if w.status in ("active", "degraded"):
                gross_revenue += w.hourly_revenue_usd * w.uptime * HOURS_PER_TICK
                w.credits_usd -= w.hourly_cost_usd * HOURS_PER_TICK
                if w.credits_usd <= 0:
                    w.credits_usd = 0.0
                    w.status = "failed"  # ran out of AKT runway

        return {"gross_revenue_usd": round(gross_revenue, 4)}

    # ------------------------------------------------------------------ #
    # Live query (best effort)
    # ------------------------------------------------------------------ #

    def _query_live_leases(self) -> Optional[list]:
        try:
            out = subprocess.run(
                ["akash", "query", "market", "lease", "list", "--output", "json"],
                capture_output=True, text=True, timeout=15,
            )
            if out.returncode != 0:
                return None
            return json.loads(out.stdout).get("leases", [])
        except Exception:
            return None

    def _merge_live(self, state: SovereignState, leases: list) -> None:
        known = {w.dseq for w in state.workers}
        for lease in leases:
            lid = lease.get("lease", {}).get("lease_id", {})
            dseq = str(lid.get("dseq", ""))
            if dseq and dseq not in known:
                w = self.provision(gpu_model="H100" if self._lease_endpoints.get("miner") else None)
                w.dseq = dseq
                w.provider = str(lid.get("provider", w.provider))
                state.workers.append(w)
        # Inject configured dual-service endpoints as synthetic workers if empty
        if not state.workers and self._lease_endpoints:
            for profile, url in self._lease_endpoints.items():
                gpu = "H100" if profile == "miner" else "RTX4090"
                if profile == "backend":
                    gpu = "RTX3090"
                w = self.provision(gpu_model=gpu)
                w.dseq = f"lease-{profile}"
                w.provider = url
                state.workers.append(w)


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))
