"""Cryptographic driver identity — IoTeX + EVM compatible secp256k1 keys."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from kairo.models.driver import DriverIdentity, utc_now

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
BECH32_CONST = 1
IOTEX_HRP = "io"


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


def _bech32_encode(hrp: str, data: bytes) -> str:
    converted = _convertbits(list(data), 8, 5, pad=True)
    combined = converted + _create_checksum(hrp, converted)
    return hrp + "1" + "".join(CHARSET[d] for d in combined)


def _convertbits(data: list[int], frombits: int, tobits: int, pad: bool) -> list[int]:
    acc = 0
    bits = 0
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


def _create_checksum(hrp: str, data: list[int]) -> list[int]:
    values = _hrp_expand(hrp) + data
    polymod = _polymod(values + [0, 0, 0, 0, 0, 0]) ^ BECH32_CONST
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]


def _keccak256(data: bytes) -> bytes:
    try:
        return hashlib.new("keccak_256", data).digest()
    except ValueError:
        from Crypto.Hash import keccak

        digest = keccak.new(digest_bits=256)
        digest.update(data)
        return digest.digest()


def _private_key_from_seed(seed: bytes) -> ec.EllipticCurvePrivateKey:
    scalar = int.from_bytes(seed, "big") % ec.SECP256K1().key_size
    if scalar == 0:
        scalar = 1
    return ec.derive_private_key(scalar, ec.SECP256K1())


def _public_key_bytes(private_key: ec.EllipticCurvePrivateKey) -> bytes:
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint,
    )


def evm_address_from_public_key(public_key: bytes) -> str:
    """Derive checksummed-style lowercase EVM address from uncompressed pubkey."""
    if public_key[0] == 4:
        public_key = public_key[1:]
    digest = _keccak256(public_key)
    return "0x" + digest[-20:].hex()


def iotex_address_from_evm(evm_address: str) -> str:
    """Encode the same 20-byte identity as an IoTeX Bech32 address (io1...)."""
    raw = bytes.fromhex(evm_address.removeprefix("0x"))
    return _bech32_encode(IOTEX_HRP, raw)


def _encryption_key() -> bytes:
    material = os.environ.get("KAIRO_IDENTITY_ENCRYPTION_KEY") or os.environ.get(
        "WALLET_ENCRYPTION_KEY", "yieldswarm-dev-kairo-key"
    )
    return hashlib.sha256(material.encode("utf-8")).digest()


def encrypt_private_key(private_key_hex: str) -> str:
    aes = AESGCM(_encryption_key())
    nonce = secrets.token_bytes(12)
    ciphertext = aes.encrypt(nonce, private_key_hex.encode("utf-8"), None)
    return json.dumps({"nonce": nonce.hex(), "ciphertext": ciphertext.hex()})


def decrypt_private_key(blob: str) -> str:
    payload = json.loads(blob)
    aes = AESGCM(_encryption_key())
    plaintext = aes.decrypt(bytes.fromhex(payload["nonce"]), bytes.fromhex(payload["ciphertext"]), None)
    return plaintext.decode("utf-8")


def generate_driver_identity(driver_id: str | None = None) -> DriverIdentity:
    """Create a new persistent driver identity."""
    seed = secrets.token_bytes(32)
    private_key = _private_key_from_seed(seed)
    private_hex = private_key.private_numbers().private_value.to_bytes(32, "big").hex()
    public_key = _public_key_bytes(private_key)
    evm = evm_address_from_public_key(public_key)
    return DriverIdentity(
        driver_id=driver_id or f"kairo-{secrets.token_hex(8)}",
        evm_address=evm,
        iotex_address=iotex_address_from_evm(evm),
        public_key_hex=public_key.hex(),
        encrypted_private_key=encrypt_private_key(private_hex),
        created_at=utc_now(),
    )


class DriverStore:
    """Simple JSON file store for driver identities."""

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(os.environ.get("KAIRO_STORE_DIR", ".data/kairo"))
        self.root.mkdir(parents=True, exist_ok=True)
        self._index_path = self.root / "drivers.json"

    def _load_index(self) -> dict[str, Any]:
        if not self._index_path.exists():
            return {"drivers": {}}
        return json.loads(self._index_path.read_text(encoding="utf-8"))

    def _save_index(self, index: dict[str, Any]) -> None:
        self._index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")

    def save(self, identity: DriverIdentity) -> DriverIdentity:
        index = self._load_index()
        index["drivers"][identity.driver_id] = {
            "driver_id": identity.driver_id,
            "evm_address": identity.evm_address,
            "iotex_address": identity.iotex_address,
            "public_key_hex": identity.public_key_hex,
            "created_at": identity.created_at,
            "encrypted_private_key": identity.encrypted_private_key,
        }
        self._save_index(index)
        return identity

    def get(self, driver_id: str) -> DriverIdentity | None:
        index = self._load_index()
        row = index["drivers"].get(driver_id)
        if not row:
            return None
        return DriverIdentity(**row)

    def get_by_address(self, evm_address: str) -> DriverIdentity | None:
        target = evm_address.lower()
        index = self._load_index()
        for row in index["drivers"].values():
            if row["evm_address"].lower() == target:
                return DriverIdentity(**row)
        return None

    def list_public(self) -> list[dict[str, Any]]:
        index = self._load_index()
        return [
            {k: v for k, v in row.items() if k != "encrypted_private_key"}
            for row in index["drivers"].values()
        ]
