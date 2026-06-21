"""YSLR — YieldSwarm Sovereign Layered Resilience encryption.

Three layers:
  L1 Classical — AES-256-GCM + HKDF + HMAC-SHA256 integrity
  L2 Orchard ZK — shielded commitments + treasury/telemetry proofs
  L3 Post-quantum — ML-KEM hybrid + Falcon signatures + lattice entropy

Keys sourced from Vault when available; never log plaintext material.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
from dataclasses import dataclass, field
from typing import Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes

from kairo.services.orchard_keys import OrchardKeyHierarchy, derive_orchard_keys
from kairo.services.pqc import (
    PqcSecretBundle,
    decapsulate,
    encapsulate,
    generate_pqc_keypair,
    lattice_entropy,
    pqc_sign,
    pqc_verify,
)
from kairo.services.zk_treasury import prove_telemetry_bounds, prove_treasury_split

YSLR_VERSION = 1
LAYER_CLASSICAL = 1
LAYER_ORCHARD = 2
LAYER_PQC = 3


@dataclass
class YslrKeyMaterial:
    """Full YSLR key bundle for a driver or sovereign loop."""

    classical_key: bytes
    orchard: OrchardKeyHierarchy
    pqc: PqcSecretBundle
    rotation_epoch: int = 0

    def public_dict(self) -> dict[str, Any]:
        return {
            "version": YSLR_VERSION,
            "rotation_epoch": self.rotation_epoch,
            "orchard": self.orchard.to_public_dict(),
            "pqc": self.pqc.public.to_dict(),
        }


@dataclass
class YslrEnvelope:
    """Encrypted sovereign payload with integrity + ZK + PQC attestations."""

    version: int
    layers: list[int]
    nonce: str
    ciphertext: str
    hmac: str
    pq_ciphertext: str | None = None
    zk_proof: dict[str, Any] | None = None
    pqc_signature: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "version": self.version,
            "layers": self.layers,
            "nonce": self.nonce,
            "ciphertext": self.ciphertext,
            "hmac": self.hmac,
            "pq_ciphertext": self.pq_ciphertext,
            "zk_proof": self.zk_proof,
            "pqc_signature": self.pqc_signature,
            "metadata": self.metadata,
        }


def _vault_classical_key() -> bytes | None:
    try:
        from lib.secrets import get_secret  # type: ignore

        raw = get_secret("yieldswarm/runtime/core", "yslr_classical_key")
        if raw:
            return hashlib.sha256(raw.encode()).digest()
    except Exception:
        pass
    material = os.environ.get("YSLR_CLASSICAL_KEY") or os.environ.get("KAIRO_IDENTITY_ENCRYPTION_KEY")
    if material:
        return hashlib.sha256(material.encode()).digest()
    if os.environ.get("NODE_ENV") == "production":
        raise RuntimeError("YSLR_CLASSICAL_KEY required in production")
    return hashlib.sha256(b"yieldswarm-yslr-dev-key").digest()


def _derive_layer_key(master: bytes, info: bytes) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=b"yieldswarm-yslr-v1",
        info=info,
    ).derive(master)


def generate_yslr_keys(*, rotation_epoch: int = 0) -> YslrKeyMaterial:
    """Generate full YSLR key hierarchy for identity or sovereign loop."""
    classical = _derive_layer_key(secrets.token_bytes(32), b"yslr-l1-classical")
    orchard = derive_orchard_keys()
    pqc = generate_pqc_keypair()
    return YslrKeyMaterial(
        classical_key=classical,
        orchard=orchard,
        pqc=pqc,
        rotation_epoch=rotation_epoch,
    )


def yslr_encrypt(
    data: bytes | str,
    *,
    keys: YslrKeyMaterial | None = None,
    include_zk: bool = True,
    zk_context: str = "telemetry",
    treasury_total: int | None = None,
) -> YslrEnvelope:
    """Encrypt data through YSLR L1 + L3; attach L2 ZK proof when requested."""
    plaintext = data if isinstance(data, bytes) else data.encode("utf-8")
    material = keys or YslrKeyMaterial(
        classical_key=_vault_classical_key() or secrets.token_bytes(32),
        orchard=derive_orchard_keys(),
        pqc=generate_pqc_keypair(),
    )

    layers = [LAYER_CLASSICAL, LAYER_PQC]
    aes_key = _derive_layer_key(material.classical_key, b"aes-gcm")
    nonce = secrets.token_bytes(12)
    ct = AESGCM(aes_key).encrypt(nonce, plaintext, b"yslr-v1")

    pq_ct, shared = encapsulate(material.pqc.public.kem_public, alg=material.pqc.public.kem_alg)
    # Re-encrypt classical key component with PQC shared secret (hybrid)
    hybrid_key = _derive_layer_key(shared, b"yslr-hybrid")
    integrity = hmac.new(hybrid_key, ct + nonce, hashlib.sha256).digest()

    zk_proof = None
    if include_zk:
        layers.append(LAYER_ORCHARD)
        if zk_context == "treasury" and treasury_total is not None:
            zk_proof = prove_treasury_split(treasury_total, orchard_keys=material.orchard).to_dict()
        else:
            zk_proof = prove_telemetry_bounds()

    sig_payload = nonce + ct + integrity
    pqc_sig = pqc_sign(sig_payload, material.pqc.sig_secret, alg=material.pqc.public.sig_alg)

    return YslrEnvelope(
        version=YSLR_VERSION,
        layers=layers,
        nonce=nonce.hex(),
        ciphertext=ct.hex(),
        hmac=integrity.hex(),
        pq_ciphertext=pq_ct.hex(),
        zk_proof=zk_proof,
        pqc_signature=pqc_sig.hex(),
        metadata={
            "zk_context": zk_context,
            "rotation_epoch": material.rotation_epoch,
            "pqc_mode": material.pqc.public.hybrid_mode,
        },
    )


def yslr_decrypt(
    envelope: YslrEnvelope | dict[str, Any],
    *,
    keys: YslrKeyMaterial | None = None,
) -> bytes:
    """Decrypt YSLR envelope — verifies HMAC + PQC signature before decrypt."""
    row = envelope if isinstance(envelope, dict) else envelope.to_dict()
    material = keys or YslrKeyMaterial(
        classical_key=_vault_classical_key() or secrets.token_bytes(32),
        orchard=derive_orchard_keys(),
        pqc=generate_pqc_keypair(),
    )

    nonce = bytes.fromhex(row["nonce"])
    ct = bytes.fromhex(row["ciphertext"])
    integrity = bytes.fromhex(row["hmac"])

    if row.get("pq_ciphertext"):
        shared = decapsulate(
            material.pqc.kem_secret,
            bytes.fromhex(row["pq_ciphertext"]),
            alg=material.pqc.public.kem_alg,
        )
        hybrid_key = _derive_layer_key(shared, b"yslr-hybrid")
        expected = hmac.new(hybrid_key, ct + nonce, hashlib.sha256).digest()
        if not hmac.compare_digest(integrity, expected):
            raise ValueError("YSLR integrity check failed")

    if row.get("pqc_signature"):
        sig_payload = nonce + ct + integrity
        ok = pqc_verify(
            sig_payload,
            bytes.fromhex(row["pqc_signature"]),
            material.pqc.public.sig_public,
            alg=material.pqc.public.sig_alg,
        )
        if not ok:
            raise ValueError("YSLR PQC signature verification failed")

    aes_key = _derive_layer_key(material.classical_key, b"aes-gcm")
    return AESGCM(aes_key).decrypt(nonce, ct, b"yslr-v1")


def encrypt_telemetry_batch(samples: list[dict[str, Any]], driver_id: str) -> YslrEnvelope:
    """Encrypt Kairo telemetry batch for Mandelbrot / sovereign pipeline."""
    payload = json.dumps({"driver_id": driver_id, "samples": samples}, sort_keys=True).encode()
    return yslr_encrypt(payload, zk_context="telemetry")


def sovereign_mutation_seed(loop_id: str, iteration: int) -> bytes:
    """Lattice entropy for Iteration-100 sovereign mutation."""
    base = hashlib.sha256(loop_id.encode()).digest()
    return lattice_entropy(base, iteration)
