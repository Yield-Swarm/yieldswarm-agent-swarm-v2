"""Cryptographic signing and verification for telemetry payloads."""

from __future__ import annotations

import hashlib
import json
from typing import Any

from eth_account import Account
from eth_account.messages import encode_defunct

from kairo.models.schemas import SignedTelemetryIn, TelemetryPayload


def canonical_json(data: dict[str, Any]) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def payload_hash(payload: TelemetryPayload) -> str:
    body = canonical_json(payload.canonical_dict())
    return hashlib.sha256(body.encode()).hexdigest()


def sign_payload(payload: TelemetryPayload, private_key_hex: str) -> str:
    """Client-side helper — sign canonical telemetry for YieldSwarm ingestion."""
    h = payload_hash(payload)
    message = encode_defunct(hexstr=h)
    signed = Account.sign_message(message, private_key=private_key_hex)
    return "0x" + signed.signature.hex()


def verify_telemetry_signature(
    data: SignedTelemetryIn, expected_evm_address: str
) -> tuple[bool, str]:
    h = payload_hash(data.payload)
    message = encode_defunct(hexstr=h)
    try:
        recovered = Account.recover_message(
            message,
            signature=bytes.fromhex(data.signature_hex.removeprefix("0x")),
        )
    except Exception:
        return False, h
    return recovered.lower() == expected_evm_address.lower(), h
