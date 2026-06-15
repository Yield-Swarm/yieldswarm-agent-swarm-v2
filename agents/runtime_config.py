"""Runtime secret validation for Vault-injected workloads."""

from __future__ import annotations

import os
from collections.abc import Iterable


class MissingRuntimeSecret(RuntimeError):
    """Raised when a required Vault-rendered secret is absent."""


def require_env(names: Iterable[str]) -> dict[str, str]:
    """Return required environment values or fail without printing secrets."""
    values: dict[str, str] = {}
    missing: list[str] = []

    for name in names:
        value = os.environ.get(name)
        if value:
            values[name] = value
        else:
            missing.append(name)

    if missing:
        joined = ", ".join(sorted(missing))
        raise MissingRuntimeSecret(f"missing Vault-injected runtime secrets: {joined}")

    return values


def optional_env(name: str, default: str = "") -> str:
    """Read optional runtime configuration without exposing the value in logs."""
    return os.environ.get(name, default)
