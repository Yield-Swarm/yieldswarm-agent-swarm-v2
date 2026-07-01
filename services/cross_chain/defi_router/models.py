"""Data models for DeFiRouter route simulation and execution."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class Chain(str, Enum):
    ETHEREUM = "ethereum"
    ARBITRUM = "arbitrum"
    AVALANCHE = "avalanche"
    CURVE = "curve"


class ProviderKind(str, Enum):
    BRIDGE = "bridge"
    SWAP = "swap"


@dataclass
class AssetPosition:
    symbol: str
    amount_usd: float
    chain: Chain


@dataclass
class Portfolio:
    """Treasury positions to route."""

    positions: List[AssetPosition]

    @property
    def total_usd(self) -> float:
        return round(sum(p.amount_usd for p in self.positions), 2)

    @classmethod
    def yieldswarm_default(cls) -> "Portfolio":
        return cls(
            positions=[
                AssetPosition("ETH", 16.0, Chain.ETHEREUM),
                AssetPosition("CURVE_LP", 14.0, Chain.CURVE),
                AssetPosition("AVAX", 2.50, Chain.AVALANCHE),
            ]
        )


@dataclass
class FeeLine:
    label: str
    cost_usd: float

    @property
    def pct_of_portfolio(self) -> float:
        return 0.0  # set by caller


@dataclass
class RouteStep:
    action: str
    provider: str
    from_chain: str
    to_chain: str
    input_usd: float
    output_usd: float
    fee_usd: float
    gas_usd: float = 0.0
    notes: str = ""


@dataclass
class RoutePlan:
    strategy_id: str
    strategy_name: str
    steps: List[RouteStep]
    total_fees_usd: float
    net_output_usd: float
    fee_pct: float
    retention_pct: float
    fee_breakdown: List[FeeLine] = field(default_factory=list)
    providers_used: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "strategyId": self.strategy_id,
            "strategyName": self.strategy_name,
            "totalFeesUsd": round(self.total_fees_usd, 2),
            "netOutputUsd": round(self.net_output_usd, 2),
            "feePct": round(self.fee_pct, 1),
            "retentionPct": round(self.retention_pct, 1),
            "providersUsed": self.providers_used,
            "feeBreakdown": [
                {"label": f.label, "costUsd": round(f.cost_usd, 2)} for f in self.fee_breakdown
            ],
            "steps": [
                {
                    "action": s.action,
                    "provider": s.provider,
                    "fromChain": s.from_chain,
                    "toChain": s.to_chain,
                    "inputUsd": s.input_usd,
                    "outputUsd": round(s.output_usd, 2),
                    "feeUsd": round(s.fee_usd, 2),
                    "gasUsd": round(s.gas_usd, 2),
                    "notes": s.notes,
                }
                for s in self.steps
            ],
        }


@dataclass
class CircuitBreakerResult:
    triggered: bool
    threshold_pct: float
    actual_fee_pct: float
    reason: str
    recommendation: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "triggered": self.triggered,
            "thresholdPct": self.threshold_pct,
            "actualFeePct": round(self.actual_fee_pct, 1),
            "reason": self.reason,
            "recommendation": self.recommendation,
        }


@dataclass
class SimulationReport:
    portfolio_usd: float
    best_route: RoutePlan
    all_routes: List[RoutePlan]
    circuit_breaker: CircuitBreakerResult
    execute: bool
    sensitivity: List[Dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "portfolioUsd": self.portfolio_usd,
            "bestRoute": self.best_route.to_dict(),
            "allRoutes": [r.to_dict() for r in self.all_routes],
            "circuitBreaker": self.circuit_breaker.to_dict(),
            "execute": self.execute,
            "sensitivity": self.sensitivity,
        }


@dataclass
class NotionTxLog:
    tx_hash: str
    step: str
    provider: str
    input_usd: float
    output_usd: float
    fee_usd: float
    chain: str
    timestamp_iso: str
    notes: str = ""
