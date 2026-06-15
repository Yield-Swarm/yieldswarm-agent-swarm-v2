"""Import-safe shim for ``agents/akash-optimizer.py``.

The Akash container entrypoint runs ``python -m agents.akash_optimizer``
after Vault Agent has rendered the runtime environment. This module
verifies that the secrets required by the optimizer are present (sourced
from Vault, never the image) and then delegates to the legacy script.

Secrets are read from the process environment, which the entrypoint
populates by sourcing ``/run/apn/secrets/apn.env`` -- the dotenv file
rendered by Vault Agent from the apn KV tree.
"""
from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path

REQUIRED_ENV = (
    "AGENTSWARM_MASTER_KEY",
    "AGENT_SHARD_ID",
    "AGENT_COUNT_TOTAL",
)


def _assert_runtime_secrets() -> None:
    """Fail fast if Vault Agent did not deliver mandatory secrets."""
    missing = [name for name in REQUIRED_ENV if not os.environ.get(name)]
    if missing:
        sys.stderr.write(
            "[apn] missing runtime env vars after Vault render: "
            f"{', '.join(missing)}\n"
        )
        raise SystemExit(78)  # EX_CONFIG


def main() -> None:
    _assert_runtime_secrets()
    script = Path(__file__).with_name("akash-optimizer.py")
    if not script.is_file():
        sys.stderr.write(f"[apn] legacy script not found: {script}\n")
        raise SystemExit(1)
    runpy.run_path(str(script), run_name="__main__")


if __name__ == "__main__":
    main()
