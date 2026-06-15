"""HashiCorp Vault storage for Kairo driver private keys and mnemonics."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Optional


def _vault_token() -> str:
    token = os.environ.get("VAULT_TOKEN", "")
    if token:
        return token
    role_id = os.environ.get("VAULT_ROLE_ID", "")
    secret_id = os.environ.get("VAULT_SECRET_ID", "")
    if role_id and secret_id and os.environ.get("VAULT_ADDR"):
        try:
            import hvac  # type: ignore

            client = hvac.Client(url=os.environ["VAULT_ADDR"])
            resp = client.auth.approle.login(role_id=role_id, secret_id=secret_id)
            return resp["auth"]["client_token"]
        except Exception:
            pass
    raise RuntimeError("VAULT_TOKEN or VAULT_ROLE_ID+VAULT_SECRET_ID required")


def _vault_request(method: str, path: str, body: Optional[dict] = None) -> dict:
    addr = os.environ.get("VAULT_ADDR", "").rstrip("/")
    if not addr:
        raise RuntimeError("VAULT_ADDR required for key storage")
    token = _vault_token()

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


def store_driver_secrets(driver_id: str, private_key_hex: str, mnemonic: str) -> str:
    """Write driver key material to Vault KV v2 (never on local disk in production)."""
    path = f"yieldswarm/data/kairo/drivers/{driver_id}"
    _vault_request(
        "POST",
        path,
        {
            "data": {
                "private_key": private_key_hex,
                "mnemonic": mnemonic,
                "derivation_path": "m/44'/60'/0'/0/0",
            }
        },
    )
    return f"yieldswarm/kairo/drivers/{driver_id}"


def store_driver_key(driver_id: str, private_key_hex: str) -> str:
    """Backward-compatible: store private key only."""
    path = f"yieldswarm/data/kairo/drivers/{driver_id}"
    _vault_request("POST", path, {"data": {"private_key": private_key_hex}})
    return f"yieldswarm/kairo/drivers/{driver_id}"


def load_driver_secrets(driver_id: str) -> Optional[dict[str, str]]:
    path = f"yieldswarm/data/kairo/drivers/{driver_id}"
    try:
        resp = _vault_request("GET", path)
        return resp.get("data", {}).get("data", {})
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def load_driver_key(driver_id: str) -> Optional[str]:
    secrets = load_driver_secrets(driver_id)
    if not secrets:
        return None
    return secrets.get("private_key")
