"""Stellar + Cosmos (Node 5 / PyHackathon) cross-chain strategy."""

from __future__ import annotations

from typing import Any, Dict

from nodes.node5.orchestrator import Node5Orchestrator
from services.cross_chain.great_delta import route_revenue_to_treasury
from services.cross_chain.strategies.base import BaseStrategy
from services.cross_chain.types import ExecutionReceipt, ExecutionStatus, StrategyJob


class StellarCosmosStrategy(BaseStrategy):
    venue = "node5_pyhackathon"
    chain = "stellar+cosmos"

    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        action = job.params.get("action", "status")
        orch = Node5Orchestrator()
        report = orch.run_cycle(actions=[action] if action != "full" else None)

        if not report.get("ok"):
            return self._receipt(
                job,
                status=ExecutionStatus.FAILED,
                error=str(report.get("results")),
                metrics=report,
            )

        gross = float(job.params.get("gross_revenue_usd", 0.0))
        split = None
        if gross > 0:
            split = route_revenue_to_treasury(gross, source="node5", strategy="stellar_cosmos")

        tx_refs: list[str] = []
        for result in report.get("results", {}).values():
            if isinstance(result, dict):
                pay = result.get("stellar_payment", {})
                if pay.get("tx_hash"):
                    tx_refs.append(str(pay["tx_hash"]))

        status = ExecutionStatus.DRY_RUN if report.get("dry_run") else ExecutionStatus.QUOTED
        return self._receipt(
            job,
            status=status,
            gross_revenue_usd=gross,
            treasury_split=split,
            tx_refs=tx_refs,
            metrics=report,
        )
