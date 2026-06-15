"""Kairo driver node — cryptographic identity and signed telemetry for YieldSwarm."""

from kairo.identity import generate_driver_identity, evm_to_iotex_address
from kairo.signing import sign_telemetry, verify_telemetry_signature, canonicalize_payload
from kairo.mandelbrot import route_telemetry, upsert_contribution

__all__ = [
    "generate_driver_identity",
    "evm_to_iotex_address",
    "sign_telemetry",
    "verify_telemetry_signature",
    "canonicalize_payload",
    "route_telemetry",
    "upsert_contribution",
]
