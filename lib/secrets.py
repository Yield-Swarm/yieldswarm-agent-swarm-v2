"""HashiCorp Vault secret loader for YieldSwarm / Kairo / Odysseus runtimes."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Mapping, Optional

VAULT_ADDR_ENV = "VAULT_ADDR"
VAULT_TOKEN_ENV = "VAULT_TOKEN"
VAULT_ROLE_ID_ENV = "VAULT_ROLE_ID"
VAULT_SECRET_ID_ENV = "VAULT_SECRET_ID"
KV_MOUNT_DEFAULT = "yieldswarm"


@dataclass(frozen=True)
class RuntimeSecrets:
    core: Mapping[str, str] = field(default_factory=dict)
    llm: Mapping[str, str] = field(default_factory=dict)
    wallets: Mapping[str, str] = field(default_factory=dict)
    integrations: Mapping[str, str] = field(default_factory=dict)
    kairo: Mapping[str, str] = field(default_factory=dict)
    payments: Mapping[str, str] = field(default_factory=dict)
    odysseus: Mapping[str, str] = field(default_factory=dict)
    bittensor: Mapping[str, str] = field(default_factory=dict)

    def get(self, key: str, default: Optional[str] = None) -> Optional[str]:
        for bucket in (
            self.core,
            self.llm,
            self.wallets,
            self.integrations,
            self.kairo,
            self.payments,
            self.odysseus,
            self.bittensor,
        ):
            if key in bucket:
                return bucket[key]
        return os.getenv(key, default)


def _vault_available() -> bool:
    return bool(os.getenv(VAULT_ADDR_ENV))


def _read_kv_path(mount: str, path: str) -> dict[str, str]:
    try:
        import hvac  # type: ignore
    except ImportError:
        return {}

    addr = os.getenv(VAULT_ADDR_ENV)
    if not addr:
        return {}

    client = hvac.Client(url=addr)
    token = os.getenv(VAULT_TOKEN_ENV)
    role_id = os.getenv(VAULT_ROLE_ID_ENV)
    secret_id = os.getenv(VAULT_SECRET_ID_ENV)

    if token:
        client.token = token
    elif role_id and secret_id:
        resp = client.auth.approle.login(role_id=role_id, secret_id=secret_id)
        client.token = resp["auth"]["client_token"]
    else:
        return {}

    try:
        secret = client.secrets.kv.v2.read_secret_version(
            path=path,
            mount_point=mount,
            raise_on_deleted_version=False,
        )
        data = secret.get("data", {}).get("data", {})
        return {str(k): str(v) for k, v in data.items() if v is not None}
    except Exception:
        return {}


@lru_cache(maxsize=1)
def load_runtime_secrets(mount: str = KV_MOUNT_DEFAULT) -> RuntimeSecrets:
    if not _vault_available():
        return RuntimeSecrets()

    return RuntimeSecrets(
        core=_read_kv_path(mount, "runtime/core"),
        llm=_read_kv_path(mount, "runtime/llm"),
        wallets=_read_kv_path(mount, "runtime/wallets"),
        integrations=_read_kv_path(mount, "integrations"),
        kairo=_read_kv_path(mount, "runtime/kairo"),
        payments=_read_kv_path(mount, "runtime/payments"),
        odysseus=_read_kv_path(mount, "runtime/odysseus"),
        bittensor=_read_kv_path(mount, "runtime/bittensor"),
    )


def require_secret(key: str, mount: str = KV_MOUNT_DEFAULT) -> str:
    value = load_runtime_secrets(mount).get(key)
    if not value:
        raise RuntimeError(
            f"Required secret '{key}' not found in Vault ({mount}) or environment"
        )
    return value
