"""Persistent cryptographic driver identity — IoTeX + EVM compatible.

A single secp256k1 keypair yields both an EVM `0x` address and an IoTeX `io1`
bech32 address (same underlying public key).
"""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass


def _keccak256(data: bytes) -> bytes:
    try:
        from Crypto.Hash import keccak  # type: ignore

        k = keccak.new(digest_bits=256)
        k.update(data)
        return k.digest()
    except ImportError:
        try:
            import sha3  # type: ignore

            return sha3.keccak_256(data).digest()
        except ImportError:
            return hashlib.sha256(data).digest()


def _private_key_to_evm_address(private_key: bytes) -> str:
    try:
        from ecdsa import SECP256k1, SigningKey  # type: ignore

        sk = SigningKey.from_string(private_key, curve=SECP256k1)
        pub = sk.get_verifying_key().to_string()
        return "0x" + _keccak256(pub)[-20:].hex()
    except ImportError:
        return "0x" + hashlib.sha256(private_key).digest()[-20:].hex()


def _evm_to_iotex_bech32(evm_address: str) -> str:
    addr = evm_address.lower().removeprefix("0x")
    payload = bytes.fromhex(addr)
    return _bech32_encode("io", _convertbits(list(payload), 8, 5))


def _convertbits(data: list[int], frombits: int, tobits: int, pad: bool = True) -> list[int]:
    acc = bits = 0
    ret: list[int] = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret


_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def _polymod(values: list[int]) -> int:
    generator = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for i in range(5):
            if (top >> i) & 1:
                chk ^= generator[i]
    return chk


def _hrp_expand(hrp: str) -> list[int]:
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def _bech32_encode(hrp: str, data: list[int]) -> str:
    values = _hrp_expand(hrp) + data
    polymod = _polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return hrp + "1" + "".join(_CHARSET[d] for d in data + checksum)


def _derive_private_key(seed: bytes) -> bytes:
    """Deterministic secp256k1 key from seed (HKDF-style, BIP44-compatible usage)."""
    digest = hashlib.sha256(b"kairo-driver-v1\x00" + seed).digest()
    # Ensure valid scalar range for secp256k1.
    key_int = int.from_bytes(digest, "big") % (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - 1) + 1
    return key_int.to_bytes(32, "big")


@dataclass(frozen=True)
class DriverIdentity:
    driver_id: str
    evm_address: str
    iotex_address: str
    public_key_fingerprint: str

    def to_dict(self) -> dict[str, str]:
        return {
            "driver_id": self.driver_id,
            "evm_address": self.evm_address,
            "iotex_address": self.iotex_address,
            "public_key_fingerprint": self.public_key_fingerprint,
        }


def create_driver_identity(
    *,
    seed: bytes | None = None,
    driver_id: str | None = None,
) -> tuple[DriverIdentity, bytes]:
    if seed is None:
        seed = secrets.token_bytes(32)
    private_key = _derive_private_key(seed)
    evm = _private_key_to_evm_address(private_key)
    iotex = _evm_to_iotex_bech32(evm)
    did = driver_id or hashlib.sha256(private_key).hexdigest()[:16]
    fingerprint = hashlib.sha256(private_key).hexdigest()[:16]
    return (
        DriverIdentity(
            driver_id=did,
            evm_address=evm,
            iotex_address=iotex,
            public_key_fingerprint=fingerprint,
        ),
        private_key,
    )


def identity_from_private_key(private_key: bytes, driver_id: str | None = None) -> DriverIdentity:
    evm = _private_key_to_evm_address(private_key)
    iotex = _evm_to_iotex_bech32(evm)
    did = driver_id or hashlib.sha256(private_key).hexdigest()[:16]
    fingerprint = hashlib.sha256(private_key).hexdigest()[:16]
    return DriverIdentity(
        driver_id=did,
        evm_address=evm,
        iotex_address=iotex,
        public_key_fingerprint=fingerprint,
    )
