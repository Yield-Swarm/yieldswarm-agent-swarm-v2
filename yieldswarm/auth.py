"""Swarm API key resolution from Cursor / process environment."""

from __future__ import annotations

import os
from typing import Optional


def resolve_primary_key(cli_key: Optional[str] = None) -> str:
    """Resolve SWARM_API_KEY_PRIMARY with documented fallbacks."""
    candidates = (
        cli_key,
        os.environ.get("SWARM_API_KEY_PRIMARY"),
        os.environ.get("AGENTSWARM_MASTER_KEY"),
    )
    for value in candidates:
        if value and value.strip():
            return value.strip()
    raise RuntimeError(
        "SWARM_API_KEY_PRIMARY is not set. "
        "Bind it in Cursor ENV / .env or export AGENTSWARM_MASTER_KEY."
    )


def resolve_backend_key(cli_key: Optional[str] = None) -> Optional[str]:
    """Resolve SWARM_API_KEY_BACKEND (optional secondary gateway)."""
    candidates = (
        cli_key,
        os.environ.get("SWARM_API_KEY_BACKEND"),
        os.environ.get("YIELDSWARM_ROUTER_API_KEY"),
    )
    for value in candidates:
        if value and value.strip():
            return value.strip()
    return None


def validate_key(provided: str, expected: str) -> None:
    if provided != expected:
        raise PermissionError("Invalid swarm API key")
