#!/usr/bin/env python3
"""Run live LLM council consensus on the next operational step."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from agents.governance.llm_consensus_engine import (  # noqa: E402
    list_active_voters,
    run_llm_consensus,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="YieldSwarm LLM next-step consensus")
    parser.add_argument("--list-voters", action="store_true", help="List configured voters")
    parser.add_argument("--context", default="", help="Situation context for the council")
    parser.add_argument("--context-file", help="Read context from file (e.g. real-world report)")
    parser.add_argument("--options-json", help='JSON array of {id,label,detail}')
    parser.add_argument("--proposal", default="", help="Optional proposal text")
    parser.add_argument(
        "--output",
        default=".run/llm-consensus-report.json",
        help="Report output path",
    )
    args = parser.parse_args()

    if args.list_voters:
        print(json.dumps({"voters": list_active_voters()}, indent=2))
        return 0

    context = args.context
    if args.context_file:
        context = Path(args.context_file).read_text(encoding="utf-8")

    if not context.strip():
        context = (
            "YieldSwarm Helix stack: 14 pillars, tri-solenoid Nexus/Helix/Shadow, "
            "backend :8080, $5408 cloud credits, Tesla/Starlink neural mesh."
        )

    if args.options_json:
        options = json.loads(args.options_json)
    else:
        options = [
            {
                "id": "deploy_pillars",
                "label": "Lock 14 pillars",
                "detail": "npm run helix:deploy-pillars + Mayhem validation",
            },
            {
                "id": "wire_tesla",
                "label": "Wire Tesla Fleet live",
                "detail": "POST /api/telemetry/tesla with partner keys",
            },
            {
                "id": "llm_consensus",
                "label": "Expand LLM voter mesh",
                "detail": "Add keys to config/governance/llm_voters.json",
            },
            {
                "id": "trident_mainnet",
                "label": "Trident mainnet deploy",
                "detail": "npm run trident:deploy after Vault secrets",
            },
        ]

    report = run_llm_consensus(
        context=context,
        options=options,
        proposal=args.proposal or None,
        output_path=args.output,
    )
    print(json.dumps(report, indent=2))
    return 0 if report["consensus"]["threshold_met"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
