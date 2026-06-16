"""Base strategy interface."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict

from services.cross_chain.types import ExecutionReceipt, StrategyJob


class BaseStrategy(ABC):
    venue: str = "unknown"
    chain: str = "unknown"

    @abstractmethod
    def execute(self, job: StrategyJob) -> ExecutionReceipt:
        """Run one strategy job and return a receipt."""

    def _receipt(
        self,
        job: StrategyJob,
        *,
        status,
        gross_revenue_usd: float = 0.0,
        treasury_split=None,
        tx_refs=None,
        metrics=None,
        error: str | None = None,
    ) -> ExecutionReceipt:
        from services.cross_chain.types import ExecutionStatus

        return ExecutionReceipt(
            job_id=job.id,
            kind=job.kind,
            status=status if isinstance(status, ExecutionStatus) else ExecutionStatus(status),
            gross_revenue_usd=gross_revenue_usd,
            treasury_split=treasury_split,
            chain=self.chain,
            venue=self.venue,
            tx_refs=tx_refs or [],
            metrics=metrics or {},
            error=error,
        )
