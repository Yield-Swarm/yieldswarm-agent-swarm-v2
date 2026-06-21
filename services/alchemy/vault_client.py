"""Fetch Alchemy API key exclusively from HashiCorp Vault at runtime."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Optional

from lib.secrets import KV_MOUNT_DEFAULT, _read_kv_path, load_runtime_secrets

VAULT_RPC_ETHEREUM_PATH = "rpc/ethereum"
VAULT_INTEGRATIONS_ALCHEMY_PATH = "integrations/alchemy"
ENV_ALCHEMY_API_KEY = "ALCHEMY_API_KEY"
ENV_ALCHEMY_KEY_PREFIX_HINT = "ALCHEMY_KEY_PREFIX_HINT"


def mask_api_key(key: str) -> str:
    """Return a safe display form (prefix + ellipsis)."""
    if not key:
        return "(unset)"
    if len(key) <= 12:
        return f"{key[:4]}…"
    return f"{key[:12]}…"


@lru_cache(maxsize=1)
def get_alchemy_api_key(*, mount: str = KV_MOUNT_DEFAULT) -> str:
    """
  Resolve Alchemy API key for Christopher's First App (or configured app).

  Order:
    1. Vault KV `yieldswarm/rpc/ethereum` → `alchemy_api_key`
    2. Vault KV `yieldswarm/integrations/alchemy` → `api_key`
    3. Environment `ALCHEMY_API_KEY` (local dev / CI injection from Vault export)

  Never reads from source files or CLI arguments.
  """
    for path, field in (
        (VAULT_RPC_ETHEREUM_PATH, "alchemy_api_key"),
        (VAULT_INTEGRATIONS_ALCHEMY_PATH, "api_key"),
    ):
        data = _read_kv_path(mount, path)
        value = data.get(field)
        if value:
            return str(value)

    runtime = load_runtime_secrets(mount)
    for alias in ("alchemy_api_key", "ALCHEMY_API_KEY"):
        value = runtime.get(alias)
        if value:
            return str(value)

    env_value = os.getenv(ENV_ALCHEMY_API_KEY)
    if env_value:
        return env_value

    raise RuntimeError(
        "Alchemy API key not found. Seed Vault "
        f"({mount}/{VAULT_RPC_ETHEREUM_PATH} or {mount}/{VAULT_INTEGRATIONS_ALCHEMY_PATH}) "
        f"or set {ENV_ALCHEMY_API_KEY} from a Vault export — never hardcode in repo."
    )


def validate_key_prefix(key: str) -> Optional[str]:
    """Warn when key prefix does not match operator hint (non-fatal)."""
    hint = os.getenv(ENV_ALCHEMY_KEY_PREFIX_HINT, "").strip()
    if hint and not key.startswith(hint):
        return f"API key prefix does not match {ENV_ALCHEMY_KEY_PREFIX_HINT}; continuing."
    return None
