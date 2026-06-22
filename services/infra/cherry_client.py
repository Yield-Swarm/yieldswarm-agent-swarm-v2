"""Cherry Servers API health probe (Vault-backed credentials)."""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, List, Optional

from services.infra.cherry_vault import CHERRY_API_BASE, cherry_auth_headers, mask_api_key


@dataclass
class CherryHealthResult:
    ok: bool
    latency_ms: float
    team_count: int = 0
    api_key_mask: str = ""
    error: Optional[str] = None
    teams: Optional[List[dict[str, Any]]] = None


def check_cherry_api(*, timeout_s: float = 20.0) -> CherryHealthResult:
    """GET /v1/teams — validates Bearer token without exposing the key."""
    headers = cherry_auth_headers()
    req = urllib.request.Request(
        f"{CHERRY_API_BASE}/teams",
        headers=headers,
        method="GET",
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            body = resp.read().decode("utf-8")
        latency_ms = (time.perf_counter() - started) * 1000.0
        payload = json.loads(body)
        teams = payload if isinstance(payload, list) else payload.get("data", [])
        if not isinstance(teams, list):
            teams = []
        auth_header = headers.get("Authorization", "")
        token = auth_header.removeprefix("Bearer ").strip()
        return CherryHealthResult(
            ok=True,
            latency_ms=latency_ms,
            team_count=len(teams),
            api_key_mask=mask_api_key(token),
            teams=teams[:5],
        )
    except urllib.error.HTTPError as exc:
        latency_ms = (time.perf_counter() - started) * 1000.0
        detail = exc.read().decode("utf-8", errors="replace")[:200]
        return CherryHealthResult(
            ok=False,
            latency_ms=latency_ms,
            error=f"HTTP {exc.code}: {detail}",
            api_key_mask=mask_api_key(headers.get("Authorization", "").removeprefix("Bearer ")),
        )
    except Exception as exc:  # noqa: BLE001
        latency_ms = (time.perf_counter() - started) * 1000.0
        return CherryHealthResult(
            ok=False,
            latency_ms=latency_ms,
            error=str(exc),
        )
