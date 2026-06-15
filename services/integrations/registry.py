"""Council Wishlist integration registry — health checks and bootstrap."""

from __future__ import annotations

import time
from typing import Any

from services.integrations.cloudflare import cloudflare_health
from services.integrations.config import CouncilIntegrationConfig, hydrate_council_env, load_council_config
from services.integrations.pinata import pinata_health
from services.integrations.rpc import rpc_health
from services.integrations.sentry_init import init_sentry, sentry_health
from services.integrations.tenderly import tenderly_health

# Livepeer intentionally excluded per user request.
_COUNCIL_SERVICES = (
    "quicknode",
    "tenderly",
    "sentry",
    "cloudflare",
    "pinata",
    "infura",
    "ankr",
)


def check_all_integrations(*, init_observability: bool = True) -> dict[str, Any]:
    """Probe all Council Wishlist integrations (except Livepeer)."""
    hydrate_council_env()
    config = load_council_config()

    rpc = rpc_health(config)
    tenderly = tenderly_health(config)
    cloudflare = cloudflare_health(config)
    pinata = pinata_health(config)

    sentry = init_sentry(config) if init_observability else sentry_health(config)

    services = {
        "quicknode": rpc["providers"].get("quicknode", {"configured": False, "live": False}),
        "infura": rpc["providers"].get("infura", {"configured": False, "live": False}),
        "ankr": rpc["providers"].get("ankr", {"configured": False, "live": False}),
        "tenderly": tenderly,
        "sentry": sentry,
        "cloudflare": cloudflare,
        "pinata": pinata,
        "livepeer": {"configured": False, "live": False, "skipped": True},
    }

    configured = [name for name in _COUNCIL_SERVICES if services[name].get("configured")]
    live = [name for name in _COUNCIL_SERVICES if services[name].get("live")]

    return {
        "generated_at": time.time(),
        "council_wishlist": list(_COUNCIL_SERVICES),
        "livepeer_skipped": True,
        "configured_count": len(configured),
        "live_count": len(live),
        "configured_services": configured,
        "live_services": live,
        "services": services,
        "rpc_failover": {
            "count": rpc.get("failover_count", 0),
            "primary_set": bool(rpc.get("primary")),
        },
        "config_summary": config.to_public(),
    }


def integration_status() -> dict[str, Any]:
    """Lightweight status for health endpoints."""
    report = check_all_integrations(init_observability=False)
    return {
        "configured_count": report["configured_count"],
        "live_count": report["live_count"],
        "configured_services": report["configured_services"],
        "live_services": report["live_services"],
        "livepeer_skipped": True,
    }
