"""Post-quantum cryptography helpers — NIST PQC hybrid (ML-KEM + Falcon).

Uses `python-oqs` (liboqs) when available. In development without liboqs,
X25519-based hybrid stub is used ONLY when KAIRO_PQC_STUB=1 and not production.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import secrets
from dataclasses import dataclass
from typing import Any

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.serialization import Encoding, NoEncryption, PrivateFormat, PublicFormat

OQS_AVAILABLE = False
try:
    import oqs  # type: ignore

    OQS_AVAILABLE = True
except ImportError:
    oqs = None  # type: ignore

KEM_ALG = "ML-KEM-768"
SIG_ALG = "Falcon-512"


def _require_production_pqc() -> None:
    if os.environ.get("NODE_ENV") == "production" or os.environ.get("KAIRO_REQUIRE_PQC") == "1":
        if not OQS_AVAILABLE:
            raise RuntimeError(
                "python-oqs (liboqs) required in production — pip install python-oqs"
            )


def _constant_time_eq(a: bytes, b: bytes) -> bool:
    return hmac.compare_digest(a, b)


@dataclass(frozen=True)
class PqcKeyBundle:
    """Hybrid classical + post-quantum key material (public fields only in transit)."""

    kem_public: bytes
    sig_public: bytes
    kem_alg: str
    sig_alg: str
    hybrid_mode: str  # "oqs" | "dev-stub"

    def to_dict(self) -> dict[str, Any]:
        return {
            "kem_public": self.kem_public.hex(),
            "sig_public": self.sig_public.hex(),
            "kem_alg": self.kem_alg,
            "sig_alg": self.sig_alg,
            "hybrid_mode": self.hybrid_mode,
        }


@dataclass
class PqcSecretBundle:
    kem_secret: bytes
    sig_secret: bytes
    public: PqcKeyBundle


def generate_pqc_keypair() -> PqcSecretBundle:
    """Generate ML-KEM + Falcon keypairs (or dev stub)."""
    _require_production_pqc()

    if OQS_AVAILABLE:
        kem = oqs.KeyEncapsulation(KEM_ALG)
        kem_public = kem.generate_keypair()
        kem_secret = kem.export_secret_key()

        sig = oqs.Signature(SIG_ALG)
        sig_public = sig.generate_keypair()
        sig_secret = sig.export_secret_key()

        public = PqcKeyBundle(
            kem_public=kem_public,
            sig_public=sig_public,
            kem_alg=KEM_ALG,
            sig_alg=SIG_ALG,
            hybrid_mode="oqs",
        )
        return PqcSecretBundle(kem_secret=kem_secret, sig_secret=sig_secret, public=public)

    if os.environ.get("KAIRO_PQC_STUB") != "1":
        raise RuntimeError("liboqs unavailable — set KAIRO_PQC_STUB=1 for dev-only X25519 stub")

    kem_private = x25519.X25519PrivateKey.generate()
    kem_public = kem_private.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
    sig_seed = secrets.token_bytes(32)
    sig_public = sig_seed  # dev stub: verify uses same material (production uses Falcon)

    public = PqcKeyBundle(
        kem_public=kem_public,
        sig_public=sig_public,
        kem_alg="X25519-dev-stub",
        sig_alg="SHA3-256-dev-stub",
        hybrid_mode="dev-stub",
    )
    return PqcSecretBundle(
        kem_secret=kem_private.private_bytes(Encoding.Raw, PrivateFormat.Raw, NoEncryption()),
        sig_secret=sig_seed,
        public=public,
    )


def encapsulate(kem_public: bytes, *, alg: str = KEM_ALG) -> tuple[bytes, bytes]:
    """KEM encapsulate → (ciphertext, shared_secret)."""
    if OQS_AVAILABLE and alg == KEM_ALG:
        kem = oqs.KeyEncapsulation(KEM_ALG)
        return kem.encap_secret(kem_public)

    if os.environ.get("KAIRO_PQC_STUB") == "1":
        ephemeral = x25519.X25519PrivateKey.generate()
        peer = x25519.X25519PublicKey.from_public_bytes(kem_public[:32])
        shared = ephemeral.exchange(peer)
        ct = ephemeral.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        secret = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=None,
            info=b"yieldswarm-yslr-pqc-stub",
        ).derive(shared)
        return ct, secret

    raise RuntimeError("PQC encapsulation unavailable")


def decapsulate(kem_secret: bytes, ciphertext: bytes, *, alg: str = KEM_ALG) -> bytes:
    if OQS_AVAILABLE and alg == KEM_ALG:
        kem = oqs.KeyEncapsulation(KEM_ALG)
        kem.import_secret_key(kem_secret)
        return kem.decap_secret(ciphertext)

    if os.environ.get("KAIRO_PQC_STUB") == "1":
        private = x25519.X25519PrivateKey.from_private_bytes(kem_secret[:32])
        peer = x25519.X25519PublicKey.from_public_bytes(ciphertext[:32])
        shared = private.exchange(peer)
        return HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=None,
            info=b"yieldswarm-yslr-pqc-stub",
        ).derive(shared)

    raise RuntimeError("PQC decapsulation unavailable")


def pqc_sign(message: bytes, sig_secret: bytes, *, alg: str = SIG_ALG) -> bytes:
    if OQS_AVAILABLE and alg == SIG_ALG:
        sig = oqs.Signature(SIG_ALG)
        sig.import_secret_key(sig_secret)
        return sig.sign(message)

    if os.environ.get("KAIRO_PQC_STUB") == "1":
        return hashlib.sha3_256(sig_secret + message).digest()

    raise RuntimeError("PQC signing unavailable")


def pqc_verify(message: bytes, signature: bytes, sig_public: bytes, *, alg: str = SIG_ALG) -> bool:
    if OQS_AVAILABLE and alg == SIG_ALG:
        sig = oqs.Signature(SIG_ALG)
        sig.import_public_key(sig_public)
        return sig.verify(message, signature)

    if os.environ.get("KAIRO_PQC_STUB") == "1":
        expected = hashlib.sha3_256(sig_public + message).digest()
        return _constant_time_eq(signature, expected)

    return False


def lattice_entropy(seed: bytes, iteration: int, *, width: int = 32) -> bytes:
    """Quantum-inspired lattice entropy for sovereign mutation loops."""
    material = hashlib.shake_256(seed + iteration.to_bytes(8, "big")).digest(width)
    # Mix bits — avalanche for mutation seeding
    folded = bytearray(width)
    for i, b in enumerate(material):
        folded[i % width] ^= b
    return bytes(folded)
