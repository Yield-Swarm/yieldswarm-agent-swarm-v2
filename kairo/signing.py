"""Cryptographic signing for Kairo driving telemetry."""

from __future__ import annotations

import json
from typing import Any

from eth_account import Account
from eth_account.messages import encode_defunct


def canonicalize_payload(payload: dict[str, Any]) -> str:
    return json.dumps({k: payload[k] for k in sorted(payload)}, separators=(",", ":"))


def sign_telemetry(private_key: str, payload: dict[str, Any]) -> str:
    acct = Account.from_key(private_key)
    msg = encode_defunct(text=canonicalize_payload(payload))
    signed = acct.sign_message(msg)
    return signed.signature.hex()


def verify_telemetry_signature(payload: dict[str, Any], signature: str, signer_address: str) -> bool:
    try:
        msg = encode_defunct(text=canonicalize_payload(payload))
        recovered = Account.recover_message(msg, signature=signature)
        return recovered.lower() == signer_address.lower()
    except Exception:
        return False
