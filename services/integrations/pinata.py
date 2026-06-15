"""Pinata IPFS pinning client."""

from __future__ import annotations

from typing import Any

from services.integrations.config import CouncilIntegrationConfig, load_council_config
from services.integrations.http_util import http_json


def pinata_health(config: CouncilIntegrationConfig | None = None) -> dict[str, Any]:
    cfg = config or load_council_config()
    headers: dict[str, str] = {}
    if cfg.pinata_jwt:
        headers["Authorization"] = f"Bearer {cfg.pinata_jwt}"
    elif cfg.pinata_api_key and cfg.pinata_secret:
        headers["pinata_api_key"] = cfg.pinata_api_key
        headers["pinata_secret_api_key"] = cfg.pinata_secret
    else:
        return {"configured": False, "live": False, "service": "pinata"}

    try:
        status, body = http_json(
            "https://api.pinata.cloud/data/userPinList?status=pinned&pageLimit=1",
            headers=headers,
            timeout=8.0,
        )
    except Exception as exc:  # noqa: BLE001
        return {"configured": True, "live": False, "service": "pinata", "error": str(exc)}

    live = status == 200 and isinstance(body, dict)
    pin_count = None
    if isinstance(body, dict):
        pin_count = body.get("count")
    return {
        "configured": True,
        "live": live,
        "service": "pinata",
        "status_code": status,
        "pin_count": pin_count,
    }
