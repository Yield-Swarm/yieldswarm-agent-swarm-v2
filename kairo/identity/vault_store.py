"""Store driver private keys in HashiCorp Vault (never on disk)."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Optional


def _vault_request(method: str, path: str, body: Optional[dict] = None) -> dict:
    addr = os.environ.get("VAULT_ADDR", "").rstrip("/")
    token = os.environ.get("VAULT_TOKEN", "")
    if not addr or not token:
        raise RuntimeError("VAULT_ADDR and VAULT_TOKEN required for key storage")

    url = f"{addr}/v1/{path.lstrip('/')}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"X-Vault-Token": token, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def store_driver_key(driver_id: str, private_key_hex: str) -> str:
    """Write encrypted driver key to Vault KV v2."""
    path = f"yieldswarm/data/kairo/drivers/{driver_id}"
    _vault_request("POST", path, {"data": {"private_key": private_key_hex}})
    return f"yieldswarm/kairo/drivers/{driver_id}"


def load_driver_key(driver_id: str) -> Optional[str]:
    path = f"yieldswarm/data/kairo/drivers/{driver_id}"
    try:
        resp = _vault_request("GET", path)
        return resp.get("data", {}).get("data", {}).get("private_key")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise
