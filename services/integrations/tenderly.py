"""Tenderly simulation API client."""

from __future__ import annotations

from typing import Any

from services.integrations.config import CouncilIntegrationConfig, load_council_config
from services.integrations.http_util import http_json


def tenderly_health(config: CouncilIntegrationConfig | None = None) -> dict[str, Any]:
    cfg = config or load_council_config()
    if not (cfg.tenderly_api_key and cfg.tenderly_account and cfg.tenderly_project):
        return {"configured": False, "live": False, "service": "tenderly"}

    url = (
        f"https://api.tenderly.co/api/v1/account/{cfg.tenderly_account}"
        f"/project/{cfg.tenderly_project}"
    )
    headers = {"X-Access-Key": cfg.tenderly_api_key}
    try:
        status, body = http_json(url, headers=headers, timeout=8.0)
    except Exception as exc:  # noqa: BLE001
        return {"configured": True, "live": False, "service": "tenderly", "error": str(exc)}

    live = status == 200
    project_name = None
    if isinstance(body, dict):
        project_name = body.get("project", {}).get("name") or body.get("name")
    return {
        "configured": True,
        "live": live,
        "service": "tenderly",
        "status_code": status,
        "project": project_name,
    }
