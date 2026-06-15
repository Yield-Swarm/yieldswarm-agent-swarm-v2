#!/usr/bin/env python3
"""Load secrets from Vault Agent-rendered env file or environment.

Secrets are never hardcoded. In production, Vault Agent renders
/opt/yieldswarm/secrets.env before agents start.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

SECRETS_FILE = Path(os.environ.get("YIELDSWARM_SECRETS_FILE", "/opt/yieldswarm/secrets.env"))
REQUIRED_KEYS = [
    "AGENTSWARM_MASTER_KEY",
    "SOLANA_RPC_URL",
]


def load_secrets_file(path: Path) -> dict[str, str]:
    """Parse a dotenv-style secrets file without logging values."""
    secrets: dict[str, str] = {}
    if not path.exists():
        return secrets

    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        secrets[key.strip()] = value.strip().strip('"').strip("'")
    return secrets


def apply_secrets(secrets: dict[str, str], override: bool = False) -> None:
    """Inject secrets into process environment."""
    for key, value in secrets.items():
        if override or key not in os.environ:
            os.environ[key] = value


def validate_required(keys: list[str] | None = None) -> None:
    """Fail fast if required secrets are missing."""
    missing = [k for k in (keys or REQUIRED_KEYS) if not os.environ.get(k)]
    if missing:
        print(f"ERROR: Missing required secrets: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)


def init_secrets() -> None:
    """Load secrets from file, then validate."""
    secrets = load_secrets_file(SECRETS_FILE)
    apply_secrets(secrets)
    validate_required()
