"""Orchard-style key hierarchy for YSLR Layer 2 (shielded flows).

Implements diversifier + viewing/spending key derivation compatible with
Zcash Orchard documentation. Full Orchard requires Halo2 proving system;
this module provides key material + commitments for integration with
circuits/orchard_treasury.circom and future Halo2 prover.

See docs/YSLR.md — formal verification recommended (Ironwood-style).
"""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from typing import Any

from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


DIVERSIFIER_LEN = 11


@dataclass(frozen=True)
class OrchardKeyHierarchy:
    """Orchard-inspired key tree for shielded treasury / telemetry."""

    diversifier: bytes
    spending_key: bytes
    incoming_viewing_key: bytes
    outgoing_viewing_key: bytes
    full_viewing_key: bytes
    orchard_address_seed: bytes

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "diversifier": self.diversifier.hex(),
            "ivk_fingerprint": hashlib.sha256(self.incoming_viewing_key).hexdigest()[:16],
            "ovk_fingerprint": hashlib.sha256(self.outgoing_viewing_key).hexdigest()[:16],
            "fvk_fingerprint": hashlib.sha256(self.full_viewing_key).hexdigest()[:16],
            "address_seed": self.orchard_address_seed.hex()[:16] + "…",
        }


def _hkdf_expand(master: bytes, info: bytes, length: int = 32) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=length,
        salt=b"yieldswarm-orchard-v1",
        info=info,
    ).derive(master)


def derive_orchard_keys(master_seed: bytes | None = None) -> OrchardKeyHierarchy:
    """Derive Orchard-style key hierarchy from master seed."""
    master = master_seed or secrets.token_bytes(32)
    diversifier = secrets.token_bytes(DIVERSIFIER_LEN)

    spending_key = _hkdf_expand(master, b"orchard-spending-key")
    incoming_viewing_key = _hkdf_expand(master, b"orchard-ivk")
    outgoing_viewing_key = _hkdf_expand(master, b"orchard-ovk")
    full_viewing_key = hashlib.sha256(incoming_viewing_key + outgoing_viewing_key).digest()
    address_seed = hashlib.sha256(diversifier + full_viewing_key).digest()

    return OrchardKeyHierarchy(
        diversifier=diversifier,
        spending_key=spending_key,
        incoming_viewing_key=incoming_viewing_key,
        outgoing_viewing_key=outgoing_viewing_key,
        full_viewing_key=full_viewing_key,
        orchard_address_seed=address_seed,
    )


def shielded_commitment(value: int, blinding: bytes, orchard_keys: OrchardKeyHierarchy) -> bytes:
    """Poseidon-style commitment placeholder (hash) for shielded amount."""
    payload = (
        value.to_bytes(32, "big")
        + blinding
        + orchard_keys.orchard_address_seed
    )
    return hashlib.sha256(payload).digest()
