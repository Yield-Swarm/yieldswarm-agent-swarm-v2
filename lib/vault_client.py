"""Shared Vault client utilities for YieldSwarm agents."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any


class VaultError(RuntimeError):
    pass


def _vault_request(
    method: str,
    path: str,
    *,
    token: str | None = None,
    body: dict[str, Any] | None = None,
) -> dict[str, Any]:
    addr = os.environ.get("VAULT_ADDR")
    if not addr:
        raise VaultError("VAULT_ADDR is not set")

    url = f"{addr.rstrip('/')}/v1/{path.lstrip('/')}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-Vault-Token"] = token

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        raise VaultError(f"Vault request failed ({exc.code}): {detail}") from exc


def login_approle(role_id: str, secret_id: str) -> str:
    payload = _vault_request(
        "POST",
        "auth/approle/login",
        body={"role_id": role_id, "secret_id": secret_id},
    )
    token = payload.get("auth", {}).get("client_token")
    if not token:
        raise VaultError("AppRole login did not return a client_token")
    return token


def read_kv_secret(mount: str, path: str, *, token: str) -> dict[str, str]:
    payload = _vault_request("GET", f"{mount}/data/{path}", token=token)
    data = payload.get("data", {}).get("data")
    if not isinstance(data, dict):
        raise VaultError(f"Secret yieldswarm/{path} is missing or malformed")
    return {str(k): str(v) for k, v in data.items()}


def load_runtime_secrets_from_vault() -> dict[str, str]:
    """Load secrets when running outside the Docker entrypoint (e.g. local dev with AppRole)."""
    role_id = os.environ.get("VAULT_ROLE_ID")
    secret_id = os.environ.get("VAULT_SECRET_ID")
    if not role_id or not secret_id:
        raise VaultError("VAULT_ROLE_ID and VAULT_SECRET_ID are required")

    mount = os.environ.get("VAULT_KV_MOUNT", "yieldswarm")
    paths = os.environ.get("VAULT_SECRET_PATHS", "akash,rpc").split(",")

    token = login_approle(role_id, secret_id)
    merged: dict[str, str] = {}
    for raw_path in paths:
        path = raw_path.strip()
        if path:
            merged.update(read_kv_secret(mount, path, token=token))
    return merged


def apply_secrets_to_environ(secrets: dict[str, str]) -> None:
    for key, value in secrets.items():
        os.environ.setdefault(key.upper(), value)
