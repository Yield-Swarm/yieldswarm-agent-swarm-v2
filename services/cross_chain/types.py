"""Shared types for cross-chain strategy execution."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, Optional


class StrategyKind(str, Enum):
    UNISWAP_V4_HOOK = "uniswap_v4_hook"
    SOLANA_LIQUIDITY = "solana_liquidity"
    DYDX_PERPS = "dydx_perps"
    ALTCOIN_POW = "altcoin_pow"


class ExecutionStatus(str, Enum):
    DRY_RUN = "dry_run"
    QUOTED = "quoted"
    SUBMITTED = "submitted"
    CONFIRMED = "confirmed"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class StrategyJob:
    """One unit of work for the cross-chain executor."""

    id: str
    kind: StrategyKind
    params: Dict[str, Any]
    dry_run: bool = True
    cron_shard: Optional[int] = None


@dataclass
class ExecutionReceipt:
    """Result of a strategy run — ingested by Sovereign Loops + Arena."""

    job_id: str
    kind: StrategyKind
    status: ExecutionStatus
    gross_revenue_usd: float = 0.0
    treasury_split: Optional[Dict[str, Any]] = None
    chain: str = ""
    venue: str = ""
    tx_refs: list[str] = field(default_factory=list)
    metrics: Dict[str, Any] = field(default_factory=dict)
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "job_id": self.job_id,
            "kind": self.kind.value,
            "status": self.status.value,
            "gross_revenue_usd": self.gross_revenue_usd,
            "treasury_split": self.treasury_split,
            "chain": self.chain,
            "venue": self.venue,
            "tx_refs": self.tx_refs,
            "metrics": self.metrics,
            "error": self.error,
        }
