"""Shared Vault integration for all solenoids — dynamic secret injection."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_DIR = REPO_ROOT / "vault" / "templates"

SOLENOID_POLICIES = {
    "nexus": "nexus-runtime",
    "helix": "helix-runtime",
    "shadow": "shadow-chain-runtime",
}

PROVIDER_TEMPLATES = {
    "akash": "akash-runtime.ctmpl",
    "azure": "azure-runtime.ctmpl",
    "vast": "vast-runtime.ctmpl",
}


def template_for_provider(provider: str) -> Path:
    name = PROVIDER_TEMPLATES.get(provider.lower())
    if not name:
        raise ValueError(f"no vault template for provider: {provider}")
    path = TEMPLATE_DIR / name
    if not path.is_file():
        raise FileNotFoundError(path)
    return path


def injection_spec(provider: str, solenoid: str) -> dict[str, Any]:
    """Return Vault Agent injection metadata for a cloud provider + solenoid."""
    tpl = template_for_provider(provider)
    policy = SOLENOID_POLICIES.get(solenoid, "agent-runtime")
    return {
        "provider": provider,
        "solenoid": solenoid,
        "policy": policy,
        "template": str(tpl),
        "vault_addr": os.environ.get("VAULT_ADDR", ""),
        "kv_mount": os.environ.get("VAULT_KV_MOUNT", "yieldswarm"),
        "approle_mount": os.environ.get("VAULT_APPROLE_MOUNT", "approle"),
    }


def list_injection_targets() -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for provider in PROVIDER_TEMPLATES:
        for solenoid in SOLENOID_POLICIES:
            out.append({"provider": provider, "solenoid": solenoid, "policy": SOLENOID_POLICIES[solenoid]})
    return out
