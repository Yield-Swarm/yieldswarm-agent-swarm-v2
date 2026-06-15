"""Load Council Wishlist credentials from platform env and Vault."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Mapping, Optional

# Vault KV path -> (vault_key, env_var)
_VAULT_INTEGRATION_MAP: tuple[tuple[str, str, str], ...] = (
    ("integrations/quicknode", "api_key", "QUICKNODE_API_KEY"),
    ("integrations/quicknode", "rpc_url", "QUICKNODE_RPC_URL"),
    ("integrations/tenderly", "api_key", "TENDERLY_API_KEY"),
    ("integrations/tenderly", "account", "TENDERLY_ACCOUNT"),
    ("integrations/tenderly", "project", "TENDERLY_PROJECT"),
    ("integrations/sentry", "dsn", "SENTRY_DSN"),
    ("integrations/sentry", "environment", "SENTRY_ENVIRONMENT"),
    ("integrations/sentry", "traces_sample_rate", "SENTRY_TRACES_SAMPLE_RATE"),
    ("integrations/cloudflare", "api_token", "CLOUDFLARE_API_TOKEN"),
    ("integrations/cloudflare", "client_id", "CLOUDFLARE_CLIENT_ID"),
    ("integrations/cloudflare", "client_secret", "CLOUDFLARE_CLIENT_SECRET"),
    ("integrations/cloudflare", "zone_id", "CLOUDFLARE_ZONE_ID"),
    ("integrations/pinata", "api_key", "PINATA_API_KEY"),
    ("integrations/pinata", "secret", "PINATA_SECRET"),
    ("integrations/pinata", "jwt", "PINATA_JWT"),
    ("rpc/infura", "project_id", "INFURA_PROJECT_ID"),
    ("rpc/infura", "api_key", "INFURA_API_KEY"),
    ("rpc/infura", "sol_mainnet_rpc", "INFURA_SOL_MAINNET_RPC"),
    ("rpc/ankr", "api_key", "ANKR_API_KEY"),
    ("rpc/ankr", "multichain_rpc", "ANKR_RPC_MULTICHAIN"),
)

_COUNCIL_ENV_KEYS: tuple[str, ...] = tuple({row[2] for row in _VAULT_INTEGRATION_MAP})


@dataclass(frozen=True)
class CouncilIntegrationConfig:
    """Resolved Council Wishlist configuration (Livepeer excluded by default)."""

    quicknode_api_key: Optional[str] = None
    quicknode_rpc_url: Optional[str] = None
    tenderly_api_key: Optional[str] = None
    tenderly_account: Optional[str] = None
    tenderly_project: Optional[str] = None
    sentry_dsn: Optional[str] = None
    sentry_environment: str = "production"
    sentry_traces_sample_rate: str = "0.1"
    cloudflare_api_token: Optional[str] = None
    cloudflare_client_id: Optional[str] = None
    cloudflare_client_secret: Optional[str] = None
    cloudflare_zone_id: Optional[str] = None
    pinata_api_key: Optional[str] = None
    pinata_secret: Optional[str] = None
    pinata_jwt: Optional[str] = None
    infura_project_id: Optional[str] = None
    infura_api_key: Optional[str] = None
    infura_sol_mainnet_rpc: Optional[str] = None
    ankr_api_key: Optional[str] = None
    ankr_rpc_multichain: Optional[str] = None
    kimiclaw_consensus_key: Optional[str] = None
    configured_services: tuple[str, ...] = field(default_factory=tuple)

    def to_public(self) -> dict[str, object]:
        return {
            "configured_services": list(self.configured_services),
            "sentry_environment": self.sentry_environment,
            "rpc_providers": [
                name
                for name, url in (
                    ("quicknode", self.quicknode_rpc_url),
                    ("infura", self.infura_sol_mainnet_rpc),
                    ("ankr", self.ankr_rpc_multichain),
                )
                if url
            ],
        }


def _vault_integration_values() -> dict[str, str]:
    try:
        from lib.secrets import _read_kv_path, KV_MOUNT_DEFAULT  # noqa: PLC0415
    except ImportError:
        return {}

    merged: dict[str, str] = {}
    cache: dict[str, dict[str, str]] = {}
    for path, vault_key, env_var in _VAULT_INTEGRATION_MAP:
        if path not in cache:
            cache[path] = _read_kv_path(KV_MOUNT_DEFAULT, path)
        value = cache[path].get(vault_key)
        if value:
            merged[env_var] = value
    return merged


def _resolve(key: str, vault_values: Mapping[str, str]) -> Optional[str]:
    return os.getenv(key) or vault_values.get(key) or None


def hydrate_council_env() -> dict[str, str]:
    """Copy Vault integration secrets into os.environ when platform env is unset."""
    vault_values = _vault_integration_values()
    applied: dict[str, str] = {}
    for env_var in _COUNCIL_ENV_KEYS:
        if os.getenv(env_var):
            continue
        value = vault_values.get(env_var)
        if value:
            os.environ[env_var] = value
            applied[env_var] = env_var
    return applied


def load_council_config() -> CouncilIntegrationConfig:
    hydrate_council_env()
    vault_values = _vault_integration_values()

    fields = {
        "quicknode_api_key": _resolve("QUICKNODE_API_KEY", vault_values),
        "quicknode_rpc_url": _resolve("QUICKNODE_RPC_URL", vault_values),
        "tenderly_api_key": _resolve("TENDERLY_API_KEY", vault_values),
        "tenderly_account": _resolve("TENDERLY_ACCOUNT", vault_values),
        "tenderly_project": _resolve("TENDERLY_PROJECT", vault_values),
        "sentry_dsn": _resolve("SENTRY_DSN", vault_values),
        "sentry_environment": _resolve("SENTRY_ENVIRONMENT", vault_values) or "production",
        "sentry_traces_sample_rate": _resolve("SENTRY_TRACES_SAMPLE_RATE", vault_values) or "0.1",
        "cloudflare_api_token": _resolve("CLOUDFLARE_API_TOKEN", vault_values),
        "cloudflare_client_id": _resolve("CLOUDFLARE_CLIENT_ID", vault_values),
        "cloudflare_client_secret": _resolve("CLOUDFLARE_CLIENT_SECRET", vault_values),
        "cloudflare_zone_id": _resolve("CLOUDFLARE_ZONE_ID", vault_values),
        "pinata_api_key": _resolve("PINATA_API_KEY", vault_values),
        "pinata_secret": _resolve("PINATA_SECRET", vault_values),
        "pinata_jwt": _resolve("PINATA_JWT", vault_values),
        "infura_project_id": _resolve("INFURA_PROJECT_ID", vault_values),
        "infura_api_key": _resolve("INFURA_API_KEY", vault_values),
        "infura_sol_mainnet_rpc": _resolve("INFURA_SOL_MAINNET_RPC", vault_values),
        "ankr_api_key": _resolve("ANKR_API_KEY", vault_values),
        "ankr_rpc_multichain": _resolve("ANKR_RPC_MULTICHAIN", vault_values),
        "kimiclaw_consensus_key": _resolve("KIMICLAW_CONSENSUS_KEY", vault_values),
    }

    configured: list[str] = []
    if fields["quicknode_api_key"] or fields["quicknode_rpc_url"]:
        configured.append("quicknode")
    if fields["tenderly_api_key"] and fields["tenderly_account"] and fields["tenderly_project"]:
        configured.append("tenderly")
    if fields["sentry_dsn"]:
        configured.append("sentry")
    if fields["cloudflare_api_token"] or fields["cloudflare_zone_id"]:
        configured.append("cloudflare")
    if fields["pinata_jwt"] or (fields["pinata_api_key"] and fields["pinata_secret"]):
        configured.append("pinata")
    if fields["infura_project_id"] or fields["infura_api_key"] or fields["infura_sol_mainnet_rpc"]:
        configured.append("infura")
    if fields["ankr_api_key"] or fields["ankr_rpc_multichain"]:
        configured.append("ankr")

    return CouncilIntegrationConfig(**fields, configured_services=tuple(configured))
