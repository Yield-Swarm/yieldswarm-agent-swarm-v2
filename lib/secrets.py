"""Shared secret loading utilities.

Runtime secrets are injected by docker/entrypoint.sh via Vault.
This module validates that required env vars are present without logging values.
"""

from __future__ import annotations

import os
import sys
from typing import Sequence


class SecretError(RuntimeError):
    """Raised when a required secret is missing from the environment."""


def require_env(keys: Sequence[str]) -> dict[str, str]:
    """Return a dict of required env vars, raising SecretError if any are missing."""
    missing = [k for k in keys if not os.environ.get(k)]
    if missing:
        raise SecretError(
            f"Missing required secrets: {', '.join(missing)}. "
            "Ensure Vault AppRole injection ran successfully."
        )
    return {k: os.environ[k] for k in keys}


def get_rpc_config() -> dict[str, str | list[str]]:
    """Load RPC configuration from Vault-injected environment variables."""
    import json

    primary = os.environ.get("PRIMARY_URL") or os.environ.get("SOLANA_RPC_URL")
    if not primary:
        raise SecretError("SOLANA_RPC_URL or PRIMARY_URL must be set")

    failover_raw = os.environ.get("ENDPOINTS") or os.environ.get("FAILOVER_RPC_LIST", "[]")
    try:
        failover = json.loads(failover_raw)
    except json.JSONDecodeError as exc:
        raise SecretError("FAILOVER_RPC_LIST is not valid JSON") from exc

    return {
        "primary_url": primary,
        "failover": failover,
        "helius_api_key": os.environ.get("HELIUS_API_KEY", ""),
    }


def validate_or_exit(keys: Sequence[str]) -> None:
    """Validate secrets exist; exit with code 1 on failure (for agent startup)."""
    try:
        require_env(keys)
    except SecretError as exc:
        print(f"[secrets] {exc}", file=sys.stderr)
        sys.exit(1)
