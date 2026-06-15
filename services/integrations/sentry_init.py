"""Sentry SDK bootstrap (optional — only when DSN is configured)."""

from __future__ import annotations

import os
from typing import Any, Optional

from services.integrations.config import CouncilIntegrationConfig, load_council_config

_sentry_initialized = False


def init_sentry(config: CouncilIntegrationConfig | None = None) -> dict[str, Any]:
    global _sentry_initialized  # noqa: PLW0603
    cfg = config or load_council_config()
    if not cfg.sentry_dsn:
        return {"configured": False, "live": False, "service": "sentry"}

    if _sentry_initialized:
        return {"configured": True, "live": True, "service": "sentry", "already_initialized": True}

    try:
        import sentry_sdk  # type: ignore
    except ImportError:
        os.environ.setdefault("SENTRY_DSN", cfg.sentry_dsn)
        return {
            "configured": True,
            "live": False,
            "service": "sentry",
            "error": "sentry-sdk not installed — DSN exported to env only",
        }

    sample_rate = float(cfg.sentry_traces_sample_rate or "0.1")
    sentry_sdk.init(
        dsn=cfg.sentry_dsn,
        environment=cfg.sentry_environment,
        traces_sample_rate=sample_rate,
        send_default_pii=False,
    )
    _sentry_initialized = True
    return {
        "configured": True,
        "live": True,
        "service": "sentry",
        "environment": cfg.sentry_environment,
        "traces_sample_rate": sample_rate,
    }


def sentry_health(config: Optional[CouncilIntegrationConfig] = None) -> dict[str, Any]:
    cfg = config or load_council_config()
    if not cfg.sentry_dsn:
        return {"configured": False, "live": False, "service": "sentry"}
    return {
        "configured": True,
        "live": _sentry_initialized,
        "service": "sentry",
        "environment": cfg.sentry_environment,
    }
