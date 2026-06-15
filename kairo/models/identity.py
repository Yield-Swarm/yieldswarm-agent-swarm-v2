"""Persistent cryptographic driver identity — IoTeX + EVM compatible."""

from __future__ import annotations

import hashlib
import json
import secrets
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Optional

try:
    from eth_account import Account  # type: ignore
    from eth_account.messages import encode_defunct  # type: ignore
except ImportError:
    Account = None  # type: ignore
    encode_defunct = None  # type: ignore


@dataclass(frozen=True)
class DriverIdentity:
    """Cross-chain driver identity derived from a single master seed."""

    driver_id: str
    evm_address: str
    iotex_address: str
    public_key_hex: str
    created_at: str
    derivation_path: str = "m/44'/60'/0'/0/0"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "DriverIdentity":
        return cls(**{k: data[k] for k in cls.__dataclass_fields__})


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _derive_iotex_address(evm_address: str) -> str:
    """IoTeX uses io prefix over the same secp256k1 key material."""
    return f"io1{evm_address[2:42].lower()}"


def create_identity(seed_hex: Optional[str] = None) -> DriverIdentity:
    """Create a new driver identity from a random or supplied seed."""
    if Account is None:
        raise RuntimeError("eth-account required: pip install eth-account")

    seed = seed_hex or secrets.token_hex(32)
    account = Account.from_key(seed)
    driver_id = hashlib.sha256(account.address.encode()).hexdigest()[:16]

    return DriverIdentity(
        driver_id=driver_id,
        evm_address=account.address,
        iotex_address=_derive_iotex_address(account.address),
        public_key_hex=account.key.hex(),
        created_at=_utc_now(),
    )


def sign_message(identity_seed: str, message: str) -> dict[str, str]:
    """Sign an arbitrary message with the driver's EVM key."""
    if Account is None or encode_defunct is None:
        raise RuntimeError("eth-account required")

    account = Account.from_key(identity_seed)
    signed = account.sign_message(encode_defunct(text=message))
    return {
        "address": account.address,
        "message": message,
        "signature": signed.signature.hex(),
    }


def verify_identity_payload(payload: dict[str, Any], signature: str) -> bool:
    """Verify a signed identity attestation."""
    if Account is None or encode_defunct is None:
        return False

    address = payload.get("evm_address")
    if not address:
        return False

    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    try:
        recovered = Account.recover_message(
            encode_defunct(text=canonical),
            signature=signature,
        )
        return recovered.lower() == str(address).lower()
    except Exception:
        return False
