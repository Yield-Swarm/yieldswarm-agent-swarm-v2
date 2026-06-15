"""
Verify Ed25519/HMAC signatures on Kairo telemetry events.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import time
from typing import Any, Optional

from eth_account import Account
from eth_account.messages import encode_defunct

from kairo.identity.wallet import get_driver

MAX_EVENT_AGE_SECONDS = 300
_seen_nonces: set[str] = set()


def canonical_payload(payload: dict[str, Any]) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


def verify_evm_signature(
    evm_address: str,
    message: str,
    signature_hex: str,
) -> bool:
    try:
        recovered = Account.recover_message(
            encode_defunct(text=message),
            signature=signature_hex,
        )
        return recovered.lower() == evm_address.lower()
    except Exception:
        return False


def verify_telemetry_event(event: dict[str, Any]) -> tuple[bool, Optional[str]]:
    """
    Verify a signed telemetry event envelope.
    Returns (ok, error_reason).
    """
    required = ("driver_id", "evm_address", "payload", "nonce", "timestamp", "signature_hex")
    for key in required:
        if key not in event:
            return False, f"missing field: {key}"

    driver = get_driver(event["driver_id"])
    if driver and driver.evm_address.lower() != event["evm_address"].lower():
        return False, "address mismatch for driver_id"

    # Replay protection
    nonce = event["nonce"]
    if nonce in _seen_nonces:
        return False, "nonce replay"
    _seen_nonces.add(nonce)
    if len(_seen_nonces) > 100_000:
        _seen_nonces.clear()

    # Freshness
    try:
        from datetime import datetime

        ts = datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00"))
        age = time.time() - ts.timestamp()
        if age > MAX_EVENT_AGE_SECONDS or age < -60:
            return False, "timestamp out of window"
    except Exception:
        return False, "invalid timestamp"

    # Build signing message: driver_id|nonce|timestamp|canonical_payload
    signing_body = "|".join(
        [
            event["driver_id"],
            event["nonce"],
            event["timestamp"],
            canonical_payload(event["payload"]),
        ]
    )
    if not verify_evm_signature(event["evm_address"], signing_body, event["signature_hex"]):
        return False, "invalid signature"

    return True, None


def sign_telemetry_event(
    private_key_hex: str,
    driver_id: str,
    evm_address: str,
    event_type: str,
    payload: dict[str, Any],
    nonce: str,
    timestamp: str,
) -> dict[str, Any]:
    """Client-side helper: sign a telemetry event with the driver's private key."""
    signing_body = "|".join(
        [driver_id, nonce, timestamp, canonical_payload(payload)]
    )
    acct = Account.from_key(private_key_hex)
    sig = acct.sign_message(encode_defunct(text=signing_body))
    return {
        "driver_id": driver_id,
        "evm_address": evm_address,
        "event_type": event_type,
        "payload": payload,
        "nonce": nonce,
        "timestamp": timestamp,
        "signature_hex": sig.signature.hex(),
    }
