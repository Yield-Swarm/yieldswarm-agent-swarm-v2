"""Kairo driver cryptographic identity — IoTeX + EVM compatible."""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from eth_account import Account
from eth_account.messages import encode_defunct


@dataclass(frozen=True)
class DriverIdentity:
    """Persistent cryptographic identity for a Kairo driver."""

    driver_id: str
    evm_address: str
    iotex_address: str
    public_key: str
    created_at: str
    node_shard: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


def _derive_driver_id(seed_material: bytes) -> str:
    return hashlib.sha256(seed_material).hexdigest()[:32]


def _iotex_address_from_evm(evm_address: str) -> str:
    """IoTeX uses the same secp256k1 key material; address format differs."""
    # IoTeX io prefix addresses are derived from the same pubkey with io1 encoding.
    # For cross-chain compatibility we store the EVM checksummed address and
    # a deterministic io1-prefixed alias derived from the pubkey hash.
    addr_bytes = bytes.fromhex(evm_address[2:])
    io_hash = hashlib.sha256(b"iotex:" + addr_bytes).hexdigest()
    return f"io1{io_hash[:38]}"


def create_driver_identity(
    *,
    driver_external_id: str,
    master_seed: Optional[str] = None,
    node_shard: int = 0,
) -> tuple[DriverIdentity, str]:
    """
    Create a new driver identity from an external ID (e.g. phone hash).
    Returns (identity, private_key_hex) — store private key in Vault, never in DB.
    """
    seed = master_seed or os.environ.get("KAIRO_IDENTITY_MASTER_SEED", "yieldswarm-kairo-dev")
    material = hashlib.sha256(f"{seed}:{driver_external_id}".encode()).digest()
    private_key = hashlib.sha256(material).hexdigest()
    account = Account.from_key(private_key)

    driver_id = _derive_driver_id(material)
    identity = DriverIdentity(
        driver_id=driver_id,
        evm_address=account.address,
        iotex_address=_iotex_address_from_evm(account.address),
        public_key=account._key_obj.public_key.to_hex() if hasattr(account, "_key_obj") else private_key[:66],
        created_at=datetime.now(timezone.utc).isoformat(),
        node_shard=node_shard % 120,
    )
    return identity, private_key


def load_identity_store(path: str | Path) -> Dict[str, DriverIdentity]:
    store_path = Path(path)
    if not store_path.exists():
        return {}
    raw = json.loads(store_path.read_text())
    return {k: DriverIdentity(**v) for k, v in raw.items()}


def save_identity(store_path: str | Path, identity: DriverIdentity) -> None:
    path = Path(store_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    store = load_identity_store(path) if path.exists() else {}
    store[identity.driver_id] = identity
    path.write_text(json.dumps({k: v.to_dict() for k, v in store.items()}, indent=2))


def sign_message(private_key_hex: str, message: str) -> Dict[str, str]:
    """Sign an arbitrary message; returns signature components."""
    account = Account.from_key(private_key_hex)
    msg = encode_defunct(text=message)
    signed = account.sign_message(msg)
    return {
        "message": message,
        "signature": signed.signature.hex(),
        "signer_evm": account.address,
        "signer_iotex": _iotex_address_from_evm(account.address),
    }


def verify_driver_signature(
    evm_address: str,
    message: str,
    signature_hex: str,
) -> bool:
    try:
        msg = encode_defunct(text=message)
        recovered = Account.recover_message(msg, signature=bytes.fromhex(signature_hex))
        return recovered.lower() == evm_address.lower()
    except Exception:
        return False
