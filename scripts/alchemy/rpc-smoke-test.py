#!/usr/bin/env python3
"""
Alchemy multi-chain RPC smoke test — Vault-backed API key.

Usage:
  export VAULT_ADDR=... VAULT_TOKEN=...   # or AppRole / ALCHEMY_API_KEY from vault-export
  python3 scripts/alchemy/rpc-smoke-test.py
  python3 scripts/alchemy/rpc-smoke-test.py --limit 5 --dry-run-config
  python3 scripts/alchemy/rpc-smoke-test.py --report reports/alchemy-smoke.html
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.alchemy.health_checker import run_smoke_test
from services.alchemy.network_registry import filter_networks, load_networks
from services.alchemy.report import render_cli_summary, write_html_report, write_json_report
from services.alchemy.vault_client import get_alchemy_api_key, mask_api_key


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Alchemy multi-chain RPC smoke test (Vault key)")
    p.add_argument("--limit", type=int, default=0, help="Limit chains (0 = all)")
    p.add_argument("--family", help="Filter by rpc family (evm, solana, …)")
    p.add_argument("--slug-prefix", help="Filter networks by slug prefix")
    p.add_argument("--workers", type=int, default=8, help="Concurrent workers")
    p.add_argument(
        "--report",
        type=Path,
        default=ROOT / "reports" / "alchemy-rpc-smoke.html",
        help="HTML report output path",
    )
    p.add_argument(
        "--json",
        type=Path,
        default=ROOT / "reports" / "alchemy-rpc-smoke.json",
        help="JSON report output path",
    )
    p.add_argument(
        "--dry-run-config",
        action="store_true",
        help="Print Vault key mask + network count without RPC calls",
    )
    p.add_argument("--no-progress", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    networks = load_networks()
    networks = filter_networks(
        networks,
        family=args.family,
        slug_prefix=args.slug_prefix,
        limit=args.limit if args.limit > 0 else None,
    )

    if args.dry_run_config:
        try:
            key = get_alchemy_api_key()
            print(f"Vault/env key resolved: {mask_api_key(key)}")
        except RuntimeError as exc:
            print(f"Key not available: {exc}", file=sys.stderr)
            return 1
        print(f"Networks selected: {len(networks)}")
        return 0

    print(f"Starting smoke test across {len(networks)} Alchemy networks…", flush=True)
    report = run_smoke_test(
        networks=networks,
        max_workers=args.workers,
        progress=not args.no_progress,
    )
    print(render_cli_summary(report))

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    html_path = args.report
    if html_path.name == "alchemy-rpc-smoke.html":
        html_path = html_path.with_name(f"alchemy-rpc-smoke-{ts}.html")
    json_path = args.json
    if json_path.name == "alchemy-rpc-smoke.json":
        json_path = json_path.with_name(f"alchemy-rpc-smoke-{ts}.json")

    write_html_report(report, html_path)
    write_json_report(report, json_path)
    print(f"\nHTML report: {html_path}")
    print(f"JSON report: {json_path}")

    return 1 if report.failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
