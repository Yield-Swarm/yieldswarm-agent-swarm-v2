"""Workload decision engine — revenue-first dynamic rebalancing."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Dict, List

from services.cloud_scheduler.providers import (
    PROVIDER_PRIORITY,
    WORKLOAD_DEFAULTS,
    ProviderState,
    best_provider_for_workload,
)


@dataclass
class ScheduleDecision:
    action: str  # scale_up | scale_down | hold | migrate
    workload: str
    provider: str
    reason: str
    priority: int
    params: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "action": self.action,
            "workload": self.workload,
            "provider": self.provider,
            "reason": self.reason,
            "priority": self.priority,
            "params": self.params,
        }


class WorkloadDecisionEngine:
    """Daily ROI-driven decisions for 30-day credit harvest."""

    def __init__(self, week: int = 1):
        self.week = week
        self.dry_run = os.getenv("CLOUD_SCHEDULER_DRY_RUN", "1").lower() in ("1", "true", "yes")

    def decide(
        self,
        provider_states: Dict[str, ProviderState],
        *,
        queue_depth: int = 0,
    ) -> List[ScheduleDecision]:
        decisions: List[ScheduleDecision] = []

        # Week 1: max GPU on Akash + Vast + RunPod
        if self.week <= 1:
            for workload in ("bittensor", "inference", "training"):
                provider = best_provider_for_workload(workload, provider_states)
                if provider:
                    decisions.append(
                        ScheduleDecision(
                            action="scale_up",
                            workload=workload,
                            provider=provider,
                            reason="week1_max_gpu_utilization",
                            priority=10 if workload == "bittensor" else 8,
                            params={"gpu": WORKLOAD_DEFAULTS[workload].get("gpu")},
                        )
                    )

        # Week 2+: Grass DePIN + async queue drain
        if self.week >= 2:
            for workload in ("grass", "cpu_batch"):
                provider = best_provider_for_workload(workload, provider_states)
                if provider:
                    decisions.append(
                        ScheduleDecision(
                            action="scale_up",
                            workload=workload,
                            provider=provider,
                            reason="week2_depin_expansion",
                            priority=6,
                            params={},
                        )
                    )

        # Week 3+: shift to highest ROI daily
        if self.week >= 3:
            ranked = sorted(
                provider_states.values(),
                key=lambda s: s.roi,
                reverse=True,
            )
            if ranked and ranked[0].roi > 1.0:
                top = ranked[0].name
                decisions.append(
                    ScheduleDecision(
                        action="scale_up",
                        workload="bittensor",
                        provider=top if top in WORKLOAD_DEFAULTS["bittensor"]["providers"] else "akash",
                        reason=f"week3_roi_leader_{top}",
                        priority=12,
                        params={},
                    )
                )

        # Drain async queue
        if queue_depth > 5:
            decisions.append(
                ScheduleDecision(
                    action="hold",
                    workload="queue_drain",
                    provider="async",
                    reason=f"queue_depth_{queue_depth}",
                    priority=15,
                    params={"queue_depth": queue_depth},
                )
            )

        # Scale down idle providers with zero revenue
        for name in PROVIDER_PRIORITY:
            st = provider_states.get(name, ProviderState(name=name))
            if st.active_jobs > 0 and st.daily_revenue_usd == 0 and st.daily_spend_usd > 10:
                decisions.append(
                    ScheduleDecision(
                        action="scale_down",
                        workload="idle",
                        provider=name,
                        reason="zero_revenue_high_spend",
                        priority=3,
                        params={},
                    )
                )

        decisions.sort(key=lambda d: d.priority, reverse=True)
        return decisions
