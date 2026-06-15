"""Persistent cryptographic driver identity — IoTeX + EVM compatible.

Each driver receives a secp256k1 keypair. The EVM address is the standard
Keccak-256 hash of the uncompressed public key. The IoTeX address uses the
same underlying key material with the ``io`` prefix convention.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

from eth_account import Account
from eth_account.messages import encode_defunct


@dataclass
class DriverIdentity:
    driver_id: str
    evm_address: str
    iotex_address: str
    public_key_hex: str
    created_at: str

    def to_public_dict(self) -> dict:
        return {
            "driverId": self.driver_id,
            "evmAddress": self.evm_address,
            "iotexAddress": self.iotex_address,
            "publicKey": self.public_key_hex,
            "createdAt": self.created_at,
        }


def _evm_to_iotex(evm_address: str) -> str:
    """Map an EVM checksummed address to IoTeX ``io`` prefix form."""
    raw = evm_address.lower().replace("0x", "")
    return f"io{raw}"


def _store_path(base: Optional[str] = None) -> Path:
    root = Path(base or os.environ.get("KAIRO_IDENTITY_STORE", ".data/kairo/identities"))
    root.mkdir(parents=True, exist_ok=True)
    return root


def create_driver_identity(driver_id: Optional[str] = None, store_dir: Optional[str] = None) -> tuple[DriverIdentity, str]:
    """Create a new driver identity. Returns (public identity, private_key_hex)."""
    from datetime import datetime, timezone

    driver_id = driver_id or secrets.token_hex(8)
    acct = Account.create()
    private_key_hex = acct.key.hex()
    evm = acct.address
    identity = DriverIdentity(
        driver_id=driver_id,
        evm_address=evm,
        iotex_address=_evm_to_iotex(evm),
        public_key_hex=acct.address,  # EVM address serves as public identifier
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    _persist_identity(identity, private_key_hex, store_dir)
    return identity, private_key_hex


def _persist_identity(identity: DriverIdentity, private_key_hex: str, store_dir: Optional[str]) -> None:
    root = _store_path(store_dir)
    pub_path = root / f"{identity.driver_id}.json"
    key_path = root / f"{identity.driver_id}.key"
    pub_path.write_text(json.dumps(identity.to_public_dict(), indent=2), encoding="utf-8")
    key_path.write_text(private_key_hex, encoding="utf-8")
    key_path.chmod(0o600)


def load_identity(driver_id: str, store_dir: Optional[str] = None) -> Optional[DriverIdentity]:
    root = _store_path(store_dir)
    pub_path = root / f"{driver_id}.json"
    if not pub_path.exists():
        return None
    data = json.loads(pub_path.read_text(encoding="utf-8"))
    return DriverIdentity(
        driver_id=data["driverId"],
        evm_address=data["evmAddress"],
        iotex_address=data["iotexAddress"],
        public_key_hex=data["publicKey"],
        created_at=data["createdAt"],
    )


def load_private_key(driver_id: str, store_dir: Optional[str] = None) -> Optional[str]:
    root = _store_path(store_dir)
    key_path = root / f"{driver_id}.key"
    if not key_path.exists():
        return None
    return key_path.read_text(encoding="utf-8").strip()


def sign_message(driver_id: str, message: str, store_dir: Optional[str] = None) -> dict:
    """Sign an arbitrary message with the driver's private key."""
    pk = load_private_key(driver_id, store_dir)
    if not pk:
        raise KeyError(f"no identity for driver {driver_id}")
    acct = Account.from_key(pk)
    msg = encode_defunct(text=message)
    signed = acct.sign_message(msg)
    return {
        "driverId": driver_id,
        "evmAddress": acct.address,
        "message": message,
        "signature": signed.signature.hex(),
        "messageHash": signed.messageHash.hex(),
    }


def verify_signature(evm_address: str, message: str, signature_hex: str) -> bool:
    """Recover signer from signature and compare to expected EVM address."""
    try:
        msg = encode_defunct(text=message)
        recovered = Account.recover_message(msg, signature=bytes.fromhex(signature_hex.replace("0x", "")))
        return recovered.lower() == evm_address.lower()
    except Exception:
        return False


def identity_fingerprint(identity: DriverIdentity) -> str:
    """Stable hash for Mandelbrot shard routing."""
    payload = f"{identity.driver_id}:{identity.evm_address}".encode()
    return hashlib.sha256(payload).hexdigest()[:16]
