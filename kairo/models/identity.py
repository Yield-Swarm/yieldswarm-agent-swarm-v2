"""Persistent cryptographic driver identity — delegates to canonical services layer."""

from __future__ import annotations

from typing import Any, Optional

from kairo.models.driver import DriverIdentity
from kairo.services.identity import (
    DEFAULT_DERIVATION_PATH,
    identity_from_mnemonic,
    register_driver,
    recover_driver,
)

try:
    from eth_account import Account  # type: ignore
    from eth_account.messages import encode_defunct  # type: ignore
except ImportError:
    Account = None  # type: ignore
    encode_defunct = None  # type: ignore


def create_identity(seed_hex: Optional[str] = None) -> DriverIdentity:
    """Create identity from optional hex seed or fresh BIP39 mnemonic."""
    if seed_hex:
        from kairo.services.identity import _identity_from_private_hex

        return _identity_from_private_hex(seed_hex)

    result = register_driver(mirror_vault=False)
    return result.identity


def sign_message(identity_seed: str, message: str) -> dict[str, str]:
    """Sign message with private key hex or mnemonic."""
    if Account is None or encode_defunct is None:
        raise RuntimeError("eth-account required")

    key = identity_seed.strip()
    if " " in key:
        account = Account.from_mnemonic(key, account_path=DEFAULT_DERIVATION_PATH)
    else:
        account = Account.from_key(key)
    signed = account.sign_message(encode_defunct(text=message))
    return {
        "address": account.address,
        "message": message,
        "signature": signed.signature.hex(),
    }


def verify_identity_payload(payload: dict[str, Any], signature: str) -> bool:
    if Account is None or encode_defunct is None:
        return False

    address = payload.get("evm_address")
    if not address:
        return False

    import json

    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    try:
        recovered = Account.recover_message(
            encode_defunct(text=canonical),
            signature=signature,
        )
        return recovered.lower() == str(address).lower()
    except Exception:
        return False


__all__ = [
    "DriverIdentity",
    "DEFAULT_DERIVATION_PATH",
    "create_identity",
    "identity_from_mnemonic",
    "recover_driver",
    "register_driver",
    "sign_message",
    "verify_identity_payload",
]
