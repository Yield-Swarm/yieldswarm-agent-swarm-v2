"""Cloudflare API client."""

from __future__ import annotations

from typing import Any

from services.integrations.config import CouncilIntegrationConfig, load_council_config
from services.integrations.http_util import http_json


def cloudflare_health(config: CouncilIntegrationConfig | None = None) -> dict[str, Any]:
    cfg = config or load_council_config()
    if not cfg.cloudflare_api_token:
        return {
            "configured": bool(cfg.cloudflare_zone_id or cfg.cloudflare_client_id),
            "live": False,
            "service": "cloudflare",
        }

    headers = {"Authorization": f"Bearer {cfg.cloudflare_api_token}"}
    if cfg.cloudflare_zone_id:
        url = f"https://api.cloudflare.com/client/v4/zones/{cfg.cloudflare_zone_id}"
    else:
        url = "https://api.cloudflare.com/client/v4/user/tokens/verify"

    try:
        status, body = http_json(url, headers=headers, timeout=8.0)
    except Exception as exc:  # noqa: BLE001
        return {"configured": True, "live": False, "service": "cloudflare", "error": str(exc)}

    success = isinstance(body, dict) and body.get("success") is True
    return {
        "configured": True,
        "live": status == 200 and success,
        "service": "cloudflare",
        "status_code": status,
        "zone_configured": bool(cfg.cloudflare_zone_id),
    }
