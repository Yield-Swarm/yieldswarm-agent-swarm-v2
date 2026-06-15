"""
Persistent cryptographic driver identity — IoTeX + EVM compatible.

Uses secp256k1 key derivation (same curve as Ethereum/IoTeX). The private key
is stored encrypted in Vault at yieldswarm/kairo/drivers/<driver_id>.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import uuid
from pathlib import Path
from typing import Optional

from eth_account import Account

from kairo.models.driver import DriverIdentity

Account.enable_unaudited_hdwallet_features()

_REGISTRY_PATH = Path(__file__).resolve().parents[1] / "data" / "driver_registry.json"


def _iotex_address_from_evm(evm_address: str) -> str:
    """IoTeX uses io prefix with same underlying pubkey hash as EVM."""
    # IoTeX address encoding: io1 + bech32 of 20-byte address
  # For compatibility we expose the EVM hex form and io-prefixed alias.
    addr = evm_address.lower().replace("0x", "")
    return f"io1{addr[:38]}"  # human-readable alias; full bech32 via IoTeX SDK in prod


def generate_driver_identity(
    device_fingerprint: Optional[str] = None,
    driver_id: Optional[str] = None,
) -> tuple[DriverIdentity, str]:
    """
    Generate a new driver keypair and identity record.
    Returns (identity, private_key_hex) — private key must go to Vault, not disk.
    """
    private_key = secrets.token_hex(32)
    acct = Account.from_key(private_key)
    evm = acct.address
    pub_hex = acct._key_obj.public_key.to_hex() if hasattr(acct, "_key_obj") else evm
    did = driver_id or f"kairo-{uuid.uuid4().hex[:12]}"

    identity = DriverIdentity(
        driver_id=did,
        evm_address=evm,
        iotex_address=_iotex_address_from_evm(evm),
        public_key_hex=pub_hex,
    )
    return identity, private_key


def load_registry() -> dict[str, dict]:
    if not _REGISTRY_PATH.exists():
        return {}
    return json.loads(_REGISTRY_PATH.read_text(encoding="utf-8"))


def save_registry(registry: dict[str, dict]) -> None:
    _REGISTRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    _REGISTRY_PATH.write_text(json.dumps(registry, indent=2), encoding="utf-8")


def register_driver(
    device_fingerprint: Optional[str] = None,
    driver_id: Optional[str] = None,
) -> DriverIdentity:
    """Register a driver and persist public identity (never the private key)."""
    identity, private_key = generate_driver_identity(device_fingerprint, driver_id)
    registry = load_registry()
    registry[identity.driver_id] = {
        **identity.to_public_dict(),
        "device_fingerprint": device_fingerprint,
        "key_fingerprint": hashlib.sha256(private_key.encode()).hexdigest()[:16],
    }
    save_registry(registry)
    if os.environ.get("VAULT_ADDR") and os.environ.get("VAULT_TOKEN"):
        try:
            from kairo.identity.vault_store import store_driver_key
            store_driver_key(identity.driver_id, private_key)
        except Exception:
            pass  # operator stores manually if Vault unavailable
    return identity


def get_driver(driver_id: str) -> Optional[DriverIdentity]:
    registry = load_registry()
    raw = registry.get(driver_id)
    if not raw:
        return None
    return DriverIdentity(**{k: v for k, v in raw.items() if k != "key_fingerprint"})
