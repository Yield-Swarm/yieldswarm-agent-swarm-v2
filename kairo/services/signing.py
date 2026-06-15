"""Sign and verify Kairo driving telemetry packets."""

from __future__ import annotations

import hashlib
import json
from typing import Any

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import Prehashed

from kairo.models.driver import DriverIdentity, SignedTelemetry, utc_now
from kairo.services.identity import decrypt_private_key


def _canonical_payload(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _eip191_digest(message: bytes) -> bytes:
    prefix = b"\x19Ethereum Signed Message:\n" + str(len(message)).encode("ascii") + message
    try:
        return hashlib.new("keccak_256", prefix).digest()
    except ValueError:
        from Crypto.Hash import keccak

        digest = keccak.new(digest_bits=256)
        digest.update(prefix)
        return digest.digest()


def sign_telemetry(
    identity: DriverIdentity,
    payload: dict[str, Any],
    *,
    use_eip191: bool = True,
) -> SignedTelemetry:
    if not identity.encrypted_private_key:
        raise ValueError("driver identity missing encrypted private key")

    private_hex = decrypt_private_key(identity.encrypted_private_key)
    private_value = int(private_hex, 16)
    private_key = ec.derive_private_key(private_value, ec.SECP256K1())

    message = _canonical_payload(payload)
    digest = _eip191_digest(message) if use_eip191 else hashlib.sha256(message).digest()
    signature = private_key.sign(digest, ec.ECDSA(Prehashed(hashes.SHA256())))

    return SignedTelemetry(
        driver_id=identity.driver_id,
        evm_address=identity.evm_address,
        payload=payload,
        signature=signature.hex(),
        signed_at=utc_now(),
    )


def verify_telemetry(packet: SignedTelemetry | dict[str, Any], public_key_hex: str) -> bool:
    row = packet if isinstance(packet, dict) else packet.to_dict()
    payload = row["payload"]
    signature = bytes.fromhex(row["signature"])
    public_key = ec.EllipticCurvePublicKey.from_encoded_point(
        ec.SECP256K1(),
        bytes.fromhex(public_key_hex),
    )
    message = _canonical_payload(payload)
    digest = _eip191_digest(message)

    try:
        public_key.verify(signature, digest, ec.ECDSA(Prehashed(hashes.SHA256())))
        return True
    except Exception:
        return False
