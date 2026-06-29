"""AES-256-GCM encrypted swarm IDs (PoW / PoS / PoWUI) — Python mirror of lib/encrypted-swarm-id.mjs."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import time
from typing import Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

VERSION = 1
_TOKEN_RE = re.compile(r"^ys_(pow|pos|powui)_([A-Za-z0-9_-]+)$")


def _derive_key() -> bytes:
    material = (
        os.environ.get("SWARM_ID_ENCRYPTION_KEY")
        or os.environ.get("AGENTSWARM_MASTER_KEY")
        or "yieldswarm-dev-only-change-in-prod"
    )
    return hashlib.sha256(f"swarm-id:v{VERSION}:{material}".encode()).digest()


def mint_id(id_type: str, raw_id: str, meta: dict[str, Any] | None = None) -> str:
    key = _derive_key()
    iv = os.urandom(12)
    payload = json.dumps({"t": id_type, "p": {"id": raw_id, **(meta or {})}, "ts": int(time.time() * 1000)}).encode()
    aes = AESGCM(key)
    enc = aes.encrypt(iv, payload, None)
    # Node layout: version(1) + iv(12) + tag(16) + ciphertext
    tag, ct = enc[-16:], enc[:-16]
    blob = base64.urlsafe_b64encode(bytes([VERSION]) + iv + tag + ct).decode().rstrip("=")
    return f"ys_{id_type}_{blob}"


def mint_pow_id(raw_id: str, meta: dict[str, Any] | None = None) -> str:
    return mint_id("pow", raw_id, meta)


def mint_powui_id(raw_id: str, meta: dict[str, Any] | None = None) -> str:
    return mint_id("powui", raw_id, meta)


def redact(value: str) -> str:
    if _TOKEN_RE.match(value):
        return value[:12] + "…"
    if len(value) > 16:
        return value[:6] + "…" + value[-4:]
    return value
