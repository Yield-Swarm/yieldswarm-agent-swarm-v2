"""Cherry Servers API key — Vault-only resolution (never hardcode)."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Optional

from lib.secrets import KV_MOUNT_DEFAULT, _read_kv_path, load_runtime_secrets

VAULT_CHERRY_PATHS = ("cloud/cherry", "providers/cherry")
ENV_CHERRY_API_KEY = "CHERRY_SERVERS_API_KEY"
CHERRY_API_BASE = "https://api.cherryservers.com/v1"


def mask_api_key(key: str) -> str:
    if not key:
        return "(unset)"
    if len(key) <= 8:
        return f"{key[:4]}…"
    return f"{key[:8]}…"


@lru_cache(maxsize=1)
def get_cherry_api_key(*, mount: str = KV_MOUNT_DEFAULT) -> str:
    """
    Resolve Cherry Servers API token from Vault at runtime.

    Order:
      1. Vault `yieldswarm/cloud/cherry` → `api_key`
      2. Vault `yieldswarm/providers/cherry` → `api_key` (legacy alias)
      3. Environment `CHERRY_SERVERS_API_KEY` (operator shell / vault-export only)
    """
    for path in VAULT_CHERRY_PATHS:
        data = _read_kv_path(mount, path)
        value = data.get("api_key")
        if value:
            return str(value)

    runtime = load_runtime_secrets(mount)
    for alias in ("api_key", "CHERRY_SERVERS_API_KEY"):
        got = runtime.get(alias)
        if got:
            return str(got)

    env_value = os.getenv(ENV_CHERRY_API_KEY)
    if env_value:
        return env_value

    raise RuntimeError(
        "Cherry Servers API key not found. Seed Vault "
        f"({mount}/cloud/cherry or {mount}/providers/cherry) "
        f"or set {ENV_CHERRY_API_KEY} from a Vault export — never commit to git."
    )


def cherry_auth_headers(api_key: Optional[str] = None) -> dict[str, str]:
    token = api_key or get_cherry_api_key()
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
