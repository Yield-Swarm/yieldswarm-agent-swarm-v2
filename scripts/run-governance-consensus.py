#!/usr/bin/env python3
"""Run 100 governance consensus models (Kimiclaw 9/14 + internal gospel)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from agents.governance.consensus_engine import run_governance_consensus  # noqa: E402
from services.integrations.registry import check_all_integrations  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm governance consensus runner")
    parser.add_argument(
        "--proposal",
        default="Council Wishlist API wiring + sovereign integration bootstrap",
        help="Governance proposal text",
    )
    parser.add_argument("--models", type=int, default=100, help="Number of consensus models")
    parser.add_argument("--seed", type=int, default=100, help="Deterministic RNG seed")
    parser.add_argument(
        "--output",
        default=".run/governance-consensus-report.json",
        help="Report output path",
    )
    parser.add_argument(
        "--skip-integrations",
        action="store_true",
        help="Skip Council Wishlist integration health probe",
    )
    args = parser.parse_args()

    integration_report = None
    if not args.skip_integrations:
        integration_report = check_all_integrations()

    consensus = run_governance_consensus(
        args.proposal,
        output_path=args.output,
        model_count=args.models,
        seed=args.seed,
        configured_integrations=integration_report["configured_count"] if integration_report else 0,
    )

    summary = {
        "consensus": {
            "threshold_met": consensus["consensus"]["threshold_met"],
            "council_approvals": consensus["consensus"]["council_approvals"],
            "governance_delta": consensus["governance_delta"],
            "autopilot_ready": consensus["autopilot_ready"],
            "model_count": consensus["model_count"],
        },
        "integrations": {
            "configured_count": integration_report["configured_count"] if integration_report else None,
            "live_count": integration_report["live_count"] if integration_report else None,
            "configured_services": integration_report["configured_services"] if integration_report else None,
        },
        "output_path": consensus["output_path"],
    }
    print(json.dumps(summary, indent=2))
    return 0 if consensus["consensus"]["threshold_met"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
