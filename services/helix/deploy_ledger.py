"""HELIX deployment ledger — HMAC-signed IPFS / domain events."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LEDGER = REPO_ROOT / "config" / "deployments" / "helix-ledger.jsonl"


def _signing_key() -> bytes:
    key = (
        os.environ.get("HELIX_LEDGER_HMAC_KEY")
        or os.environ.get("SOVEREIGN_LOOP_KEY")
        or os.environ.get("HELIX_CHAIN_BRIDGE_KEY")
        or ""
    ).encode()
    if not key:
        raise RuntimeError("HELIX_LEDGER_HMAC_KEY or SOVEREIGN_LOOP_KEY required for ledger signing")
    return key


def sign_payload(payload: Dict[str, Any]) -> str:
    body = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hmac.new(_signing_key(), body, hashlib.sha256).hexdigest()


def append_entry(
    event: str,
    *,
    run_id: str,
    domain: str,
    cid_v0: Optional[str] = None,
    extra: Optional[Dict[str, Any]] = None,
    ledger_path: Path = DEFAULT_LEDGER,
) -> Dict[str, Any]:
    payload: Dict[str, Any] = {
        "runId": run_id,
        "domain": domain,
        "event": event,
        "cidV0": cid_v0,
        "recordedAt": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        payload.update(extra)
    payload["helixHmac"] = sign_payload({k: v for k, v in payload.items() if k != "helixHmac"})

    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(payload, separators=(",", ":")) + "\n")

    return payload


def verify_receipt(receipt_hex: str, payload: Dict[str, Any]) -> bool:
    expected = sign_payload(payload)
    return hmac.compare_digest(receipt_hex, expected)
