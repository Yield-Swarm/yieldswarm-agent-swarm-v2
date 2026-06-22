"""Vault client for Nexus Chain — all solenoids pull secrets via AppRole."""

from __future__ import annotations

import os
from typing import Any

try:
    from lib.secrets import load_runtime_secrets as _load_vault_secrets
except ImportError:
    _load_vault_secrets = None  # type: ignore


class NexusVaultClient:
    def __init__(self):
        self.addr = os.environ.get("VAULT_ADDR", "")
        self.mount = os.environ.get("VAULT_KV_MOUNT", "yieldswarm")

    def ping(self) -> dict[str, Any]:
        if not self.addr:
            return {"live": False, "reason": "VAULT_ADDR unset"}
        if _load_vault_secrets is None:
            return {"live": False, "reason": "lib.secrets unavailable"}
        try:
            bundle = _load_vault_secrets()
            return {
                "live": True,
                "addr": self.addr,
                "paths_loaded": list(bundle.__dict__.keys()) if hasattr(bundle, "__dict__") else [],
            }
        except Exception as exc:
            return {"live": False, "error": str(exc)}

    def paths_for_solenoid(self, solenoid_key: str) -> list[str]:
        mapping = {
            "nexus": ["treasury/manifest", "treasury/mining_roots", "runtime/backend"],
            "helix": ["treasury/mining_roots", "iotex/hub", "runtime/wallets"],
            "shadow": ["runtime/backend", "runtime/zk"],
            "iot_hub": ["iot/devices", "iot/network", "runtime/core"],
        }
        return [f"{self.mount}/data/{p}" for p in mapping.get(solenoid_key, [])]
