"""Cryptographic driver identity — IoTeX + EVM compatible.

Every Kairo driver receives a persistent keypair derived from a stable seed
(driver_id + platform salt). The same private key controls:

  - EVM address  (secp256k1, 0x-prefixed)
  - IoTeX address (same key material, io prefix via bech32)

Drivers sign all telemetry payloads with this key so YieldSwarm can attribute
data to a verified DePIN node and route rewards through the Mandelbrot pipeline.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import secrets
from dataclasses import asdict, dataclass
from typing import Any

try:
    from eth_account import Account
    from eth_account.messages import encode_defunct
except ImportError:  # pragma: no cover
    Account = None  # type: ignore
    encode_defunct = None  # type: ignore


IOTEX_HRP = "io"
PLATFORM_SALT = "kairo-yieldswarm-v1"


@dataclass(frozen=True)
class DriverIdentity:
    driver_id: str
    evm_address: str
    iotex_address: str
    public_key_hex: str

    def to_dict(self) -> dict[str, str]:
        return asdict(self)


def _derive_private_key(driver_id: str, salt: str = PLATFORM_SALT) -> bytes:
    """Deterministic 32-byte secp256k1 key from driver_id (HKDF-style)."""
    prk = hmac.new(salt.encode(), driver_id.encode(), hashlib.sha256).digest()
    return hashlib.sha256(prk + b"\x01").digest()


def _evm_to_iotex(evm_address: str) -> str:
    """Convert 0x EVM address to IoTeX io1... bech32 (simplified encoder)."""
    addr_bytes = bytes.fromhex(evm_address[2:].lower())
    # IoTeX uses bech32 with hrp "io" and version byte 0 for account addresses.
    return _bech32_encode(IOTEX_HRP, [0] + _convertbits(addr_bytes, 8, 5))


def _convertbits(data: bytes, frombits: int, tobits: int, pad: bool = True) -> list[int]:
    acc, bits, ret = 0, 0, []
    maxv = (1 << tobits) - 1
    for byte in data:
        acc = (acc << frombits) | byte
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret


def _bech32_encode(hrp: str, data: list[int]) -> str:
    """Minimal bech32 encoder (BIP-0173) for IoTeX addresses."""
    CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    def polymod(values: list[int]) -> int:
        GEN = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
        chk = 1
        for v in values:
            b = chk >> 25
            chk = ((chk & 0x1FFFFFF) << 5) ^ v
            for i in range(5):
                if (b >> i) & 1:
                    chk ^= GEN[i]
        return chk

    def hrp_expand(h: str) -> list[int]:
        return [ord(x) >> 5 for x in h] + [0] + [ord(x) & 31 for x in h]

    combined = data + _create_checksum(hrp, data)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def _create_checksum(hrp: str, data: list[int]) -> list[int]:
    values = _hrp_expand_for_checksum(hrp) + data
    polymod_val = _polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod_val >> 5 * (5 - i)) & 31 for i in range(6)]


def _hrp_expand_for_checksum(hrp: str) -> list[int]:
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def _polymod(values: list[int]) -> int:
    GEN = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ v
        for i in range(5):
            if (b >> i) & 1:
                chk ^= GEN[i]
    return chk


def create_driver_identity(driver_id: str) -> tuple[DriverIdentity, bytes]:
    """Create or recover a driver's cryptographic identity."""
    if Account is None:
        raise RuntimeError("eth-account is required: pip install eth-account")

    private_key = _derive_private_key(driver_id)
    account = Account.from_key(private_key)
    evm = account.address
    iotex = _evm_to_iotex(evm)
    try:
        from eth_keys.datatypes import PrivateKey
        pubkey = PrivateKey(private_key).public_key.to_hex()
    except Exception:
        pubkey = evm  # fallback: address serves as identity reference

    identity = DriverIdentity(
        driver_id=driver_id,
        evm_address=evm,
        iotex_address=iotex,
        public_key_hex=pubkey,
    )
    return identity, private_key


def create_ephemeral_driver() -> tuple[DriverIdentity, bytes]:
    """Generate a one-off driver identity (for onboarding before account link)."""
    driver_id = f"kairo-{secrets.token_hex(16)}"
    return create_driver_identity(driver_id)


def sign_message(private_key: bytes, message: str | dict[str, Any]) -> str:
    """Sign a message or JSON payload; returns 0x-prefixed signature."""
    if Account is None or encode_defunct is None:
        raise RuntimeError("eth-account is required")

    if isinstance(message, dict):
        payload = json.dumps(message, sort_keys=True, separators=(",", ":"))
    else:
        payload = message

    signed = Account.sign_message(encode_defunct(text=payload), private_key)
    return signed.signature.hex()


def verify_signature(
    identity: DriverIdentity,
    message: str | dict[str, Any],
    signature: str,
) -> bool:
    """Verify a driver's signature against their EVM address."""
    if Account is None or encode_defunct is None:
        raise RuntimeError("eth-account is required")

    if isinstance(message, dict):
        payload = json.dumps(message, sort_keys=True, separators=(",", ":"))
    else:
        payload = message

    try:
        recovered = Account.recover_message(
            encode_defunct(text=payload),
            signature=signature,
        )
        return recovered.lower() == identity.evm_address.lower()
    except Exception:
        return False
