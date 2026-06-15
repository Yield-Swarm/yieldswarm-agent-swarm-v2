"""Akash optimizer runtime with strict secret validation.

This process is expected to run behind deploy/akash/entrypoint.sh, which
hydrates runtime environment variables from Vault before this program starts.
"""

from __future__ import annotations

import os
import sys
from typing import Sequence


REQUIRED_SECRET_ENV: Sequence[str] = (
    "RUNPOD_API_KEY",
    "VULTR_API_KEY",
    "DIGITALOCEAN_TOKEN",
    "SOLANA_RPC_URL",
    "ETH_RPC_URL",
)


def _missing_required_env(keys: Sequence[str]) -> list[str]:
    return [key for key in keys if not os.getenv(key)]


def main() -> int:
    missing = _missing_required_env(REQUIRED_SECRET_ENV)
    if missing:
        print(
            "Startup blocked: required Vault-injected secrets are missing: "
            + ", ".join(sorted(missing)),
            file=sys.stderr,
        )
        return 1

    # Placeholder for Akash SDK integration:
    # - monitor DSEQ leases
    # - rebalance allocations across providers
    # - enforce policy for margin and uptime
    print("Akash Optimizer Agent active - runtime secrets loaded from Vault.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())