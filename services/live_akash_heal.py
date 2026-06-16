"""Live Akash lease self-healing for the sovereign runtime.

Wraps ``deploy/akash/auto-heal.sh`` and augments it with Python-side health
probes so the sovereign core can record healing events in ``dashboard/state.json``.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
AUTO_HEAL_SCRIPT = REPO_ROOT / "deploy" / "akash" / "auto-heal.sh"
LEASE_ENV = Path(os.getenv("AKASH_LEASE_ENV", REPO_ROOT / ".run" / "akash-lease.env"))


@dataclass
class HealAction:
    action: str
    detail: str
    success: bool = True
    impact_usd: float = 0.0


@dataclass
class HealReport:
    ran: bool
    live: bool
    actions: List[HealAction] = field(default_factory=list)
    lease_env: Optional[str] = None
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ran": self.ran,
            "live": self.live,
            "lease_env": self.lease_env,
            "error": self.error,
            "actions": [
                {
                    "action": a.action,
                    "detail": a.detail,
                    "success": a.success,
                    "impact_usd": a.impact_usd,
                }
                for a in self.actions
            ],
        }


def _parse_env_file(path: Path) -> Dict[str, str]:
    if not path.is_file():
        return {}
    values: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        values[key.strip()] = val.strip().strip('"').strip("'")
    return values


def lease_env_present() -> bool:
    return LEASE_ENV.is_file()


def run_auto_heal(*, once: bool = True, timeout: int = 120) -> HealReport:
    """Invoke the shell auto-heal loop (escrow top-up, manifest resend, recreate)."""
    if not lease_env_present():
        return HealReport(ran=False, live=False, error="lease env missing")

    if not AUTO_HEAL_SCRIPT.is_file():
        return HealReport(
            ran=False,
            live=False,
            lease_env=str(LEASE_ENV),
            error=f"auto-heal script missing: {AUTO_HEAL_SCRIPT}",
        )

    args = ["bash", str(AUTO_HEAL_SCRIPT)]
    if once:
        args.append("--once")

    started = time.time()
    try:
        proc = subprocess.run(
            args,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "REPO_ROOT": str(REPO_ROOT)},
        )
        output = (proc.stdout or "") + (proc.stderr or "")
        success = proc.returncode == 0
        actions = _actions_from_output(output)
        if not actions:
            actions.append(HealAction(
                action="auto_heal_cycle",
                detail=output.strip()[-500:] or "auto-heal cycle completed",
                success=success,
            ))
        return HealReport(
            ran=True,
            live=True,
            lease_env=str(LEASE_ENV),
            actions=actions,
            error=None if success else f"exit {proc.returncode}",
        )
    except subprocess.TimeoutExpired:
        return HealReport(
            ran=True,
            live=True,
            lease_env=str(LEASE_ENV),
            actions=[HealAction("auto_heal_timeout", f"timed out after {timeout}s", success=False)],
            error="timeout",
        )
    except OSError as exc:
        return HealReport(
            ran=True,
            live=True,
            lease_env=str(LEASE_ENV),
            error=str(exc),
        )
    finally:
        _ = time.time() - started


def _actions_from_output(output: str) -> List[HealAction]:
    """Best-effort parse of auto-heal.sh log lines into structured actions."""
    actions: List[HealAction] = []
    for line in output.splitlines():
        lower = line.lower()
        if "escrow topped up" in lower or "topping up deployment escrow" in lower:
            actions.append(HealAction("topup", line.strip(), success=True, impact_usd=-5.0))
        elif "manifest re-sent" in lower or "resending manifest" in lower:
            actions.append(HealAction("resend_manifest", line.strip(), success=True))
        elif "lease recreated" in lower or "recreating via create-lease" in lower:
            actions.append(HealAction("recreate_lease", line.strip(), success=True, impact_usd=-25.0))
        elif "lease inactive" in lower:
            actions.append(HealAction("lease_inactive", line.strip(), success=False))
        elif "workers healthy" in lower:
            actions.append(HealAction("health_ok", line.strip(), success=True))
        elif "health check failed" in lower:
            actions.append(HealAction("health_fail", line.strip(), success=False))
    return actions


def sync_live_worker_health(state_workers: list) -> List[HealAction]:
    """Probe live Akash worker URLs and mark matching fleet workers degraded."""
    from services.akash_worker_sync import sync_workers_from_akash

    actions: List[HealAction] = []
    live_workers = sync_workers_from_akash(probe=True)
    if not live_workers:
        return actions

    lease = _parse_env_file(LEASE_ENV)
    dseq = lease.get("AKASH_DSEQ", "")

    for live in live_workers:
        matched = None
        if dseq:
            matched = next((w for w in state_workers if str(w.dseq) == str(dseq)), None)
        if matched is None and state_workers:
            matched = state_workers[0]

        if matched is None:
            continue

        matched.health = float(live.health_score)
        matched.uptime = max(0.0, min(1.0, live.health_score))
        if live.health_score < 0.55:
            matched.status = "degraded"
            actions.append(HealAction(
                "mark_degraded",
                f"lease {matched.dseq} health {live.health_score:.2f} from probe {live.provider_uri}",
                success=False,
            ))
        elif matched.status == "degraded" and live.health_score >= 0.85:
            matched.status = "active"
            actions.append(HealAction(
                "mark_recovered",
                f"lease {matched.dseq} recovered health {live.health_score:.2f}",
                success=True,
            ))

    return actions


def heal_cycle(*, run_shell: bool = True) -> HealReport:
    """Full live heal pass: optional shell auto-heal + worker health sync."""
    enabled = os.getenv("SOVEREIGN_LIVE_HEAL", "1").lower() in ("1", "true", "yes")
    if not enabled or not lease_env_present():
        return HealReport(ran=False, live=lease_env_present())

    report = run_auto_heal(once=True) if run_shell else HealReport(ran=False, live=True, lease_env=str(LEASE_ENV))
    return report


def write_heal_status(report: HealReport, path: Optional[Path] = None) -> None:
    """Persist last heal report for the dashboard overlay."""
    out = path or (REPO_ROOT / ".run" / "akash-heal.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = report.to_dict()
    payload["timestamp"] = time.time()
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
