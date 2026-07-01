"""DeFiRouter agent orchestrator."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from services.cross_chain.defi_router.circuit_breaker import CircuitBreaker
from services.cross_chain.defi_router.models import Portfolio, SimulationReport
from services.cross_chain.defi_router.notion_logger import NotionTreasuryLogger
from services.cross_chain.defi_router.router import RouteOptimizer
from services.cross_chain.defi_router.sensitivity import min_viable_portfolio, sensitivity_analysis

REPO_ROOT = Path(__file__).resolve().parents[3]


class DeFiRouterAgent:
    """YieldSwarm treasury routing agent with fee simulation and circuit breaker."""

    def __init__(
        self,
        *,
        dry_run: Optional[bool] = None,
        fee_threshold_pct: float | None = None,
        state_dir: Optional[Path] = None,
    ):
        env_dry = os.getenv("DEFI_ROUTER_DRY_RUN", "1").lower() in ("1", "true", "yes")
        self.dry_run = env_dry if dry_run is None else dry_run
        self.optimizer = RouteOptimizer()
        self.circuit_breaker = CircuitBreaker(fee_threshold_pct)
        self.notion = NotionTreasuryLogger()
        self.state_dir = state_dir or Path(os.getenv("DEFI_ROUTER_STATE_DIR", REPO_ROOT / ".data/defi-router"))
        self.state_dir.mkdir(parents=True, exist_ok=True)

    def simulate(self, portfolio: Optional[Portfolio] = None) -> SimulationReport:
        pf = portfolio or Portfolio.yieldswarm_default()
        routes = self.optimizer.optimize(pf)
        best = routes[0]
        cb = self.circuit_breaker.evaluate(best, pf.total_usd)
        sensitivity = sensitivity_analysis()

        report = SimulationReport(
            portfolio_usd=pf.total_usd,
            best_route=best,
            all_routes=routes,
            circuit_breaker=cb,
            execute=not cb.triggered and not self.dry_run,
            sensitivity=sensitivity,
        )
        self._persist(report)
        return report

    def run(self, portfolio: Optional[Portfolio] = None) -> Dict[str, Any]:
        report = self.simulate(portfolio)
        notion_result = self.notion.log_simulation(report)

        result: Dict[str, Any] = {
            "schemaVersion": "defi-router/v1",
            "capturedAt": datetime.now(timezone.utc).isoformat(),
            "dryRun": self.dry_run,
            "report": report.to_dict(),
            "minViablePortfolioUsd": min_viable_portfolio(self.circuit_breaker.threshold_pct),
            "notion": notion_result,
        }

        if report.circuit_breaker.triggered:
            result["status"] = "HALTED"
            result["message"] = report.circuit_breaker.recommendation
        elif self.dry_run:
            result["status"] = "DRY_RUN"
            result["message"] = "Simulation complete — set DEFI_ROUTER_DRY_RUN=0 + multi-sig to execute"
        else:
            result["status"] = "EXECUTE"
            result["message"] = "Route approved — awaiting Gnosis Safe signatures"
            self.notion.log_route_steps(report.best_route, dry_run=False)

        return result

    def execution_report_text(self, report: SimulationReport) -> str:
        best = report.best_route
        cb = report.circuit_breaker
        lines = [
            "YieldSwarm DeFiRouter — Execution Report",
            "=" * 44,
            f"Portfolio Value:     ${report.portfolio_usd:.2f}",
            f"Best Strategy:       {best.strategy_name}",
            f"Projected Fees:      ${best.total_fees_usd:.2f} ({best.fee_pct:.1f}%)",
            f"Net Retained:        {best.retention_pct:.1f}% (${best.net_output_usd:.2f})",
            f"Circuit Breaker:     {'TRIGGERED' if cb.triggered else 'OK'}",
            f"Recommendation:      {cb.recommendation}",
            "",
            "Fee Breakdown",
            "-" * 44,
        ]
        for f in best.fee_breakdown:
            pct = (f.cost_usd / report.portfolio_usd * 100) if report.portfolio_usd else 0
            lines.append(f"  {f.label:<28} ${f.cost_usd:>6.2f}  ({pct:.1f}%)")
        lines.extend(["", "Strategy Comparison", "-" * 44])
        for r in report.all_routes:
            lines.append(
                f"  {r.strategy_name:<20} fees=${r.total_fees_usd:>6.2f}  "
                f"retain={r.retention_pct:.1f}%"
            )
        lines.extend(["", "Sensitivity (retention % by portfolio size)", "-" * 44])
        for row in report.sensitivity:
            flag = "✓" if row["viable"] else "✗"
            lines.append(
                f"  {flag} ${row['portfolioUsd']:>7} → {row['retentionPct']:.1f}% retained "
                f"({row['strategy']})"
            )
        return "\n".join(lines)

    def _persist(self, report: SimulationReport) -> None:
        payload = report.to_dict()
        payload["capturedAt"] = datetime.now(timezone.utc).isoformat()
        (self.state_dir / "latest.json").write_text(json.dumps(payload, indent=2))
        text = self.execution_report_text(report)
        (self.state_dir / "execution_report.txt").write_text(text)
