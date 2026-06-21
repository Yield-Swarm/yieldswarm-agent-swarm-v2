"""Mining fleet authentication — Vault + env secret gate."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# Auth paths loaded from Vault (subset of ~88 seeded secrets)
AUTH_VAULT_PATHS = [
    "runtime/core",
    "runtime/wallets",
    "runtime/bittensor",
    "mining/wallets",
    "runtime/akash",
]


@dataclass
class AuthContext:
    ok: bool
    secret_count: int = 0
    paths_loaded: List[str] = field(default_factory=list)
    master_key_configured: bool = False
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ok": self.ok,
            "secret_count": self.secret_count,
            "paths_loaded": self.paths_loaded,
            "master_key_configured": self.master_key_configured,
            "error": self.error,
        }


class MiningAuthService:
    """
    Secure auth gate for mining fleet operations.

    Uses AGENTSWARM_MASTER_KEY (or Vault runtime/core) to sign/verify
    miner instance tokens. Production miners must present a valid token
    or run with MINING_AUTH_SKIP=1 only in dev.
    """

    TOKEN_TTL_SEC = 3600

    def __init__(self) -> None:
        self._secrets: Dict[str, str] = {}
        self._load_secrets()

    def _load_secrets(self) -> None:
        try:
            from lib.secrets import _read_kv_path, KV_MOUNT_DEFAULT, load_runtime_secrets

            mount = os.getenv("VAULT_KV_MOUNT", KV_MOUNT_DEFAULT)
            merged: Dict[str, str] = {}

            runtime = load_runtime_secrets(mount)
            for bucket in (
                runtime.core,
                runtime.wallets,
                runtime.bittensor,
                runtime.odysseus,
                runtime.payments,
            ):
                merged.update(dict(bucket))

            for path in AUTH_VAULT_PATHS:
                data = _read_kv_path(mount, path)
                if data:
                    merged.update(data)
                    self._paths_loaded = getattr(self, "_paths_loaded", [])
                    self._paths_loaded.append(path)

            self._secrets = merged
        except Exception:
            self._secrets = {}
            self._paths_loaded = []

        # Overlay environment (operator .env / vault-agent rendered agent.env)
        for key, value in os.environ.items():
            if value and not key.startswith("_"):
                self._secrets.setdefault(key, value)

    @property
    def paths_loaded(self) -> List[str]:
        return getattr(self, "_paths_loaded", [])

    def bootstrap_context(self) -> AuthContext:
        master = self._signing_key()
        count = len([v for v in self._secrets.values() if v and v not in ("[REDACTED]", "")])
        skip = os.getenv("MINING_AUTH_SKIP", "").lower() in ("1", "true", "yes")
        ok = bool(master) or skip
        return AuthContext(
            ok=ok,
            secret_count=count,
            paths_loaded=self.paths_loaded,
            master_key_configured=bool(master),
            error=None if ok else "AGENTSWARM_MASTER_KEY or Vault runtime/core required",
        )

    def _signing_key(self) -> str:
        return (
            self._secrets.get("agentswarm_master_key")
            or self._secrets.get("AGENTSWARM_MASTER_KEY")
            or os.getenv("AGENTSWARM_MASTER_KEY", "")
        )

    def issue_token(self, instance_id: str, provider: str) -> str:
        key = self._signing_key()
        if not key:
            if os.getenv("MINING_AUTH_SKIP", "").lower() in ("1", "true", "yes"):
                return f"dev-{instance_id}"
            raise RuntimeError("Cannot issue token without AGENTSWARM_MASTER_KEY")

        expires = int(time.time()) + self.TOKEN_TTL_SEC
        payload = f"{instance_id}:{provider}:{expires}"
        sig = hmac.new(key.encode(), payload.encode(), hashlib.sha256).hexdigest()
        return f"{payload}:{sig}"

    def verify_token(self, token: str, instance_id: str, provider: str) -> bool:
        if os.getenv("MINING_AUTH_SKIP", "").lower() in ("1", "true", "yes"):
            return True
        if token.startswith("dev-"):
            return os.getenv("NODE_ENV") != "production"

        key = self._signing_key()
        if not key or token.count(":") < 3:
            return False

        parts = token.rsplit(":", 1)
        if len(parts) != 2:
            return False
        payload, sig = parts
        expected = hmac.new(key.encode(), payload.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected):
            return False

        try:
            iid, prov, exp_str = payload.split(":", 2)
        except ValueError:
            return False

        if iid != instance_id or prov != provider:
            return False
        if int(exp_str) < time.time():
            return False
        return True

    def require_authorized(self, instance_id: str, provider: str, token: Optional[str] = None) -> None:
        ctx = self.bootstrap_context()
        if not ctx.ok:
            raise PermissionError(ctx.error or "mining auth not configured")
        if token and not self.verify_token(token, instance_id, provider):
            raise PermissionError(f"invalid token for {provider}/{instance_id}")

    def redacted_secrets_summary(self) -> Dict[str, Any]:
        """Summary for ops dashboards — never returns raw secret values."""
        keys = sorted(self._secrets.keys())
        return {
            "total_keys": len(keys),
            "paths_loaded": self.paths_loaded,
            "has_master_key": bool(self._signing_key()),
            "has_bittensor": any("bittensor" in k or "bt_" in k.lower() for k in keys),
            "has_mining_wallets": any("mining" in k or "tao" in k.lower() for k in keys),
        }
