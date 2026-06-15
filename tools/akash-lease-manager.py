#!/usr/bin/env python3
"""
YieldSwarm Akash Lease Manager
Monitors DSEQ leases, tops up deposits, triggers auto-heal via API.
Part of Odysseus + YieldSwarm production tooling.
"""

import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path(__file__).resolve().parents[1] / ".akash-state"
LEASE_FILE = STATE_DIR / "lease.json"
API_URL = os.environ.get("API_URL", "http://localhost:3000")
MIN_DEPOSIT_UAKT = int(os.environ.get("MIN_DEPOSIT_UAKT", "1000000"))


def load_lease() -> dict | None:
    if not LEASE_FILE.exists():
        return None
    return json.loads(LEASE_FILE.read_text())


def check_health() -> bool:
    try:
        req = urllib.request.Request(f"{API_URL}/health")
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except Exception:
        return False


def trigger_heal() -> dict:
    req = urllib.request.Request(
        f"{API_URL}/api/v1/akash/leases/heal",
        method="POST",
        headers={"Content-Type": "application/json"},
        data=b"{}",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def get_lease_balance(dseq: str) -> int | None:
    key = os.environ.get("AKASH_KEY_NAME", "")
    if not key:
        return None
    try:
        result = subprocess.run(
            ["akash", "query", "deployment", "get", "--dseq", dseq, "-o", "json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        escrows = data.get("deployment", {}).get("escrow_account", {})
        return int(escrows.get("balance", {}).get("amount", 0))
    except Exception:
        return None


def top_up_deposit(dseq: str, amount_uakt: int) -> bool:
    key = os.environ.get("AKASH_KEY_NAME", "")
    if not key:
        print("AKASH_KEY_NAME not set — skip top-up")
        return False
    try:
        subprocess.run(
            [
                "akash", "tx", "deployment", "deposit", amount_uakt, "uakt",
                "--dseq", dseq,
                "--from", key,
                "--gas", "auto",
                "--gas-adjustment", "1.5",
                "--yes",
            ],
            check=True,
            timeout=60,
        )
        return True
    except Exception as e:
        print(f"Top-up failed: {e}")
        return False


def run_cycle() -> dict:
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "healthy": check_health(),
        "actions": [],
    }

    lease = load_lease()
    if lease:
        dseq = lease.get("dseq", "unknown")
        balance = get_lease_balance(dseq)
        report["dseq"] = dseq
        report["balance_uakt"] = balance

        if balance is not None and balance < MIN_DEPOSIT_UAKT:
            top_up = MIN_DEPOSIT_UAKT * 2
            if top_up_deposit(dseq, top_up):
                report["actions"].append(f"topped_up_{top_up}_uakt")

    if not report["healthy"]:
        heal = trigger_heal()
        report["actions"].append("heal_triggered")
        report["heal"] = heal

    return report


if __name__ == "__main__":
    report = run_cycle()
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["healthy"] else 1)
