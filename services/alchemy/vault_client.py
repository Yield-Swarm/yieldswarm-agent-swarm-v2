"""Resolve Alchemy API key from HashiCorp Vault — never hardcode."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Optional

from lib.secrets import KV_MOUNT_DEFAULT, _read_kv_path, load_runtime_secrets

VAULT_PATHS = (
    ("integrations/alchemy", "api_key"),
    ("rpc/ethereum", "alchemy_api_key"),
)
ENV_KEY = "ALCHEMY_API_KEY"


def mask_api_key(key: str) -> str:
    if not key:
        return "(unset)"
    return f"{key[:12]}…" if len(key) > 12 else f"{key[:4]}…"


@lru_cache(maxsize=1)
def get_alchemy_api_key(*, mount: str = KV_MOUNT_DEFAULT) -> str:
    for path, field in VAULT_PATHS:
        data = _read_kv_path(mount, path)
        if data.get(field):
            return str(data[field])

    runtime = load_runtime_secrets(mount)
    for alias in ("api_key", "alchemy_api_key", "ALCHEMY_API_KEY"):
        value = runtime.get(alias)
        if value:
            return str(value)

    env_value = os.getenv(ENV_KEY)
    if env_value:
        return env_value

    raise RuntimeError(
        f"Alchemy API key not found. Seed Vault ({mount}/integrations/alchemy) "
        f"or set {ENV_KEY} from Vault export — never commit to git."
    )


def optional_api_key(*, mount: str = KV_MOUNT_DEFAULT) -> Optional[str]:
    try:
        return get_alchemy_api_key(mount=mount)
    except RuntimeError:
        return os.getenv(ENV_KEY)
