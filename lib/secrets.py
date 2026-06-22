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
VAULT_WRAPPED_SECRET_ID_ENV = "VAULT_WRAPPED_SECRET_ID"
VAULT_SECRET_ID_WRAP_TOKEN_ENV = "VAULT_SECRET_ID_WRAP_TOKEN"
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
    mining: Mapping[str, str] = field(default_factory=dict)
    nexus: Mapping[str, str] = field(default_factory=dict)
    helix: Mapping[str, str] = field(default_factory=dict)
    shadow: Mapping[str, str] = field(default_factory=dict)
    zk: Mapping[str, str] = field(default_factory=dict)
    treasury: Mapping[str, str] = field(default_factory=dict)

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
            self.mining,
            self.nexus,
            self.helix,
            self.shadow,
            self.zk,
            self.treasury,
        ):
            if key in bucket:
                return bucket[key]
        return os.getenv(key, default)


def _unwrap_secret_id(wrap_token: str) -> Optional[str]:
    """Consume a one-shot response-wrapped SecretID and return the plaintext."""
    if not wrap_token:
        return None
    try:
        import hvac  # type: ignore
    except ImportError:
        return None

    addr = os.getenv(VAULT_ADDR_ENV)
    if not addr:
        return None

    client = hvac.Client(url=addr)
    try:
        resp = client.sys.unwrap(wrap_token)
        data = resp.get("data", resp)
        if isinstance(data, dict):
            secret = data.get("secret_id") or data.get("secretId")
            if secret:
                return str(secret)
        # Some wrap payloads nest under .data again
        inner = data.get("data") if isinstance(data, dict) else None
        if isinstance(inner, dict):
            secret = inner.get("secret_id") or inner.get("secretId")
            if secret:
                return str(secret)
    except Exception:
        return None
    return None


def _approle_login() -> Optional[str]:
    """Return a Vault token via AppRole, unwrapping SecretID when needed."""
    role_id = os.getenv(VAULT_ROLE_ID_ENV)
    secret_id = os.getenv(VAULT_SECRET_ID_ENV)
    wrap = os.getenv(VAULT_WRAPPED_SECRET_ID_ENV) or os.getenv(VAULT_SECRET_ID_WRAP_TOKEN_ENV)
    if not secret_id and wrap:
        secret_id = _unwrap_secret_id(wrap)
        if secret_id:
            os.environ[VAULT_SECRET_ID_ENV] = secret_id
            os.environ.pop(VAULT_WRAPPED_SECRET_ID_ENV, None)
            os.environ.pop(VAULT_SECRET_ID_WRAP_TOKEN_ENV, None)

    if not role_id or not secret_id:
        return None

    try:
        import hvac  # type: ignore
    except ImportError:
        return None

    addr = os.getenv(VAULT_ADDR_ENV)
    if not addr:
        return None

    client = hvac.Client(url=addr)
    resp = client.auth.approle.login(role_id=role_id, secret_id=secret_id)
    return str(resp["auth"]["client_token"])


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
    if token:
        client.token = token
    else:
        token = _approle_login()
        if not token:
            return {}
        client.token = token

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
        mining=_read_kv_path(mount, "mining/wallets"),
        nexus=_read_kv_path(mount, "runtime/nexus"),
        helix=_read_kv_path(mount, "runtime/helix"),
        shadow=_read_kv_path(mount, "runtime/shadow"),
        zk=_read_kv_path(mount, "runtime/zk"),
        treasury=_read_kv_path(mount, "treasury/mining_roots"),
    )


def require_secret(key: str, mount: str = KV_MOUNT_DEFAULT) -> str:
    value = load_runtime_secrets(mount).get(key)
    if not value:
        raise RuntimeError(
            f"Required secret '{key}' not found in Vault ({mount}) or environment"
        )
    return value
