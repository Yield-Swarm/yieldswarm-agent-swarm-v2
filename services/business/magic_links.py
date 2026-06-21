"""Magic link authentication for team members."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]

TEAM_ALLOWLIST = [
    {"name": "Myra", "email_env": "MAGIC_LINK_MYRA_EMAIL", "role": "admin"},
    {"name": "Jack", "email_env": "MAGIC_LINK_JACK_EMAIL", "role": "partner"},
    {"name": "Kyle", "email_env": "MAGIC_LINK_KYLE_EMAIL", "role": "operator"},
    {"name": "Nick", "email_env": "MAGIC_LINK_NICK_EMAIL", "role": "operator"},
    {"name": "Zeev", "email_env": "MAGIC_LINK_ZEEV_EMAIL", "role": "partner"},
]


def _secret() -> bytes:
    raw = os.environ.get("AGENTSWARM_MASTER_KEY") or os.environ.get("MAGIC_LINK_SECRET") or "magic-dev"
    return hashlib.sha256(raw.encode()).digest()


def _token_path() -> Path:
    run = Path(os.environ.get("RUN_DIR", REPO_ROOT / ".run"))
    return run / "auth" / "magic_tokens.json"


def team_roster() -> List[Dict[str, Any]]:
    roster = []
    for member in TEAM_ALLOWLIST:
        email = os.environ.get(member["email_env"], "")
        roster.append({**member, "email": email, "configured": bool(email)})
    return roster


def issue_magic_link(email: str, *, ttl_sec: int = 3600) -> Dict[str, Any]:
    token_id = str(uuid.uuid4())
    expires = int(time.time()) + ttl_sec
    payload = f"{token_id}:{email}:{expires}"
    sig = hmac.new(_secret(), payload.encode(), hashlib.sha256).hexdigest()
    token = f"{token_id}.{expires}.{sig[:32]}"

    path = _token_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    store: Dict[str, Any] = {}
    if path.exists():
        try:
            store = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            store = {}
    store[token_id] = {"email": email, "expires": expires, "used": False}
    path.write_text(json.dumps(store, indent=2), encoding="utf-8")

    base = os.environ.get("PORTAL_BASE_URL", "http://127.0.0.1:8080")
    return {
        "token": token,
        "url": f"{base}/portal/?magic={token}",
        "expires_at": expires,
        "email": email,
    }


def verify_magic_token(token: str) -> Optional[Dict[str, Any]]:
    parts = token.split(".")
    if len(parts) != 3:
        return None
    token_id, expires_s, sig = parts
    try:
        expires = int(expires_s)
    except ValueError:
        return None
    if time.time() > expires:
        return None

    path = _token_path()
    if not path.exists():
        return None
    store = json.loads(path.read_text(encoding="utf-8"))
    entry = store.get(token_id)
    if not entry or entry.get("used"):
        return None

    payload = f"{token_id}:{entry['email']}:{expires}"
    expected = hmac.new(_secret(), payload.encode(), hashlib.sha256).hexdigest()[:32]
    if not hmac.compare_digest(sig, expected):
        return None

    entry["used"] = True
    store[token_id] = entry
    path.write_text(json.dumps(store, indent=2), encoding="utf-8")
    return {"email": entry["email"], "verified": True}
