"""Production sovereign runtime — unifies simulation core with live actions.

On each cycle this module:

1. Resumes :class:`SovereignState` from ``dashboard/state.json`` (or bootstraps).
2. Runs live Akash self-healing (``auto-heal.sh --once`` + worker probes).
3. Syncs treasury allocations from the Great Delta 50/30/15/5 overlay.
4. Executes one :class:`SovereignCore` tick (mutation, healing, rebalance, reinvest).
5. Persists the unified dashboard snapshot and heal/treasury overlays.

Used by ``deploy/runtime/swarm_runner.py`` and ``agents/chainlink-vault-manager.py``.
"""

from __future__ import annotations

import json
import os
import sys
import time
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
ITERATION_100 = REPO_ROOT / "iteration-100"

for path in (str(REPO_ROOT), str(ITERATION_100)):
    if path not in sys.path:
        sys.path.insert(0, path)

from services.live_akash_heal import (  # noqa: E402
    HealReport,
    heal_cycle,
    sync_live_worker_health,
    write_heal_status,
)
from services.live_treasury import (  # noqa: E402
    compute_policy_rebalance,
    fetch_treasury_overlay,
    overlay_to_strategies,
    write_treasury_overlay,
)
from sovereign_core import CoreConfig, SovereignCore  # noqa: E402
from core.state import Event  # noqa: E402


@dataclass
class CycleReport:
    tick: int
    cycle: int
    timestamp: float
    heal: Dict[str, Any]
    treasury_policy_actions: List[Dict[str, Any]]
    treasury_moved_usd: float
    blended_apy: float
    healthy_worker_ratio: float
    net_worth_usd: float
    progress: float
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "tick": self.tick,
            "cycle": self.cycle,
            "timestamp": self.timestamp,
            "heal": self.heal,
            "treasury_policy_actions": self.treasury_policy_actions,
            "treasury_moved_usd": self.treasury_moved_usd,
            "blended_apy": self.blended_apy,
            "healthy_worker_ratio": self.healthy_worker_ratio,
            "net_worth_usd": self.net_worth_usd,
            "progress": self.progress,
            "error": self.error,
        }


class SovereignRuntime:
    """Unified autonomous sovereign loop for production and simulation."""

    def __init__(
        self,
        *,
        state_path: Optional[Path] = None,
        dashboard_path: Optional[Path] = None,
        resume: bool = True,
    ) -> None:
        self.state_path = Path(
            state_path or os.getenv("SOVEREIGN_STATE_PATH", REPO_ROOT / "dashboard" / "state.json")
        )
        self.dashboard_path = Path(
            dashboard_path or REPO_ROOT / "dashboard" / "final-monitoring-dashboard-5m.md"
        )
        self._cycle_counter = self._read_cycle_counter()
        cfg = CoreConfig(state_path=str(self.state_path))
        self.core = SovereignCore(cfg, resume=resume)

    def _read_cycle_counter(self) -> int:
        meta = REPO_ROOT / ".run" / "sovereign-meta.json"
        if meta.is_file():
            try:
                return int(json.loads(meta.read_text(encoding="utf-8")).get("cycle", 0))
            except (OSError, json.JSONDecodeError, TypeError, ValueError):
                pass
        return 0

    def _write_cycle_counter(self, cycle: int) -> None:
        meta = REPO_ROOT / ".run" / "sovereign-meta.json"
        meta.parent.mkdir(parents=True, exist_ok=True)
        meta.write_text(json.dumps({"cycle": cycle, "updated_at": time.time()}, indent=2), encoding="utf-8")

    def _apply_live_heal(self) -> HealReport:
        report = heal_cycle(run_shell=True)
        if report.live and self.core.state.workers:
            probe_actions = sync_live_worker_health(self.core.state.workers)
            for action in probe_actions:
                report.actions.append(action)
                self.core.state.log(Event(
                    self.core.state.tick,
                    "healing",
                    action.action,
                    action.detail,
                    impact_usd=action.impact_usd,
                ))
        write_heal_status(report)
        return report

    def _apply_live_treasury(self) -> tuple[List[Dict[str, Any]], float]:
        overlay = fetch_treasury_overlay()
        write_treasury_overlay(overlay)

        if overlay.splits:
            self.core.state.strategies = overlay_to_strategies(overlay)

        policy_actions, moved = compute_policy_rebalance(overlay)
        for row in policy_actions:
            self.core.state.log(Event(
                self.core.state.tick,
                "treasury",
                "policy_rebalance",
                f"{row['label']}: transfer ${row['transfer_usd']:,.0f} "
                f"(target ${row['target_usd']:,.0f})",
                impact_usd=row["transfer_usd"],
            ))
        return policy_actions, moved

    def run_cycle(self) -> Dict[str, Any]:
        """Execute one full sovereign cycle (live overlays + core tick)."""
        self._cycle_counter += 1
        cycle = self._cycle_counter
        ts = time.time()

        try:
            heal_report = self._apply_live_heal()
            policy_actions, policy_moved = self._apply_live_treasury()

            self.core.tick()

            state = self.core.state
            self._write_cycle_counter(cycle)
            self._write_dashboard_summary(cycle, heal_report, policy_actions, policy_moved)

            report = CycleReport(
                tick=state.tick,
                cycle=cycle,
                timestamp=ts,
                heal=heal_report.to_dict(),
                treasury_policy_actions=policy_actions,
                treasury_moved_usd=policy_moved,
                blended_apy=round(state.blended_apy, 4),
                healthy_worker_ratio=round(state.healthy_worker_ratio, 4),
                net_worth_usd=round(state.net_worth_usd, 2),
                progress=round(state.progress, 6),
            )
            return report.to_dict()
        except Exception as exc:  # noqa: BLE001 — sovereign loop must survive faults
            fault = {
                "tick": self.core.state.tick,
                "cycle": cycle,
                "timestamp": ts,
                "error": str(exc),
                "traceback": traceback.format_exc(),
            }
            fault_path = REPO_ROOT / ".run" / "sovereign-fault.json"
            fault_path.parent.mkdir(parents=True, exist_ok=True)
            fault_path.write_text(json.dumps(fault, indent=2), encoding="utf-8")
            raise

    def _write_dashboard_summary(
        self,
        cycle: int,
        heal_report: HealReport,
        policy_actions: List[Dict[str, Any]],
        policy_moved: float,
    ) -> None:
        """Append a concise markdown summary alongside state.json."""
        state = self.core.state
        heal_lines = "\n".join(
            f"| {a.action} | {a.detail[:80]} | {'ok' if a.success else 'fail'} |"
            for a in heal_report.actions[:8]
        ) or "| none | - | - |"
        treasury_lines = "\n".join(
            f"| {r['label']} | ${r['transfer_usd']:,.0f} | ${r['post_allocation_usd']:,.0f} |"
            for r in policy_actions[:8]
        ) or "| none | - | - |"

        md = (
            f"# Sovereign Runtime — Cycle {cycle}\n\n"
            f"Updated: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}\n\n"
            f"## Vault KPIs\n"
            f"- Tick: **{state.tick}**\n"
            f"- Net worth: **${state.net_worth_usd:,.0f}** ({state.progress:.1%} of ${state.vault_target_usd:,.0f})\n"
            f"- Blended APY: **{state.blended_apy:.1%}** (target {state.target_apy:.0%})\n"
            f"- Healthy leases: **{state.healthy_worker_ratio:.1%}**\n\n"
            f"## Live Akash Self-Heal\n"
            f"- Ran: **{heal_report.ran}** | Live lease: **{heal_report.live}**\n\n"
            f"| Action | Detail | Status |\n|---|---|---|\n{heal_lines}\n\n"
            f"## Treasury Policy Rebalance (50/30/15/5)\n"
            f"- Policy moves: **${policy_moved:,.0f}**\n\n"
            f"| Bucket | Transfer | Post Allocation |\n|---|---|---|\n{treasury_lines}\n"
        )
        self.dashboard_path.parent.mkdir(parents=True, exist_ok=True)
        self.dashboard_path.write_text(md, encoding="utf-8")


def run_cycle(
    *,
    state_path: Optional[Path] = None,
    dashboard_path: Optional[Path] = None,
) -> Dict[str, Any]:
    """Convenience entrypoint for swarm_runner and agents."""
    runtime = SovereignRuntime(state_path=state_path, dashboard_path=dashboard_path)
    return runtime.run_cycle()


def main() -> int:
    report = run_cycle()
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
