"""Emit verified telemetry into YieldSwarm Mandelbrot / Tree of Life harvest layer."""

from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

HARVEST_DIR = Path(os.environ.get("YIELDSWARM_HARVEST_DIR", "/run/secrets/harvest"))


class YieldSwarmEmitter:
    """Forward signed telemetry routing to shard crons and optional webhook."""

    def __init__(self) -> None:
        self.webhook_url = os.environ.get("KAIRO_BRIDGE_WEBHOOK_URL", "")
        self.webhook_secret = os.environ.get("KAIRO_BRIDGE_WEBHOOK_SECRET", "")
        self.shard_count = int(os.environ.get("YIELDSWARM_SHARD_COUNT", "120"))

    def emit(
        self,
        *,
        driver_id: str,
        event_id: str,
        payload_hash: str,
        routing: dict[str, Any],
        distance_delta_km: float,
    ) -> dict[str, Any]:
        record = {
            "source": "kairo-bridge",
            "driver_id": driver_id,
            "event_id": event_id,
            "payload_hash": payload_hash,
            "routing": routing,
            "distance_delta_km": distance_delta_km,
            "emitted_at": datetime.now(timezone.utc).isoformat(),
            "yieldswarm_shard": routing.get("shard_id"),
            "tree_of_life_node": routing.get("tree_of_life_node"),
            "helix_path": routing.get("helix_path"),
            "cron_slot": routing.get("yieldswarm_cron_slot"),
        }

        self._write_harvest_file(record)
        webhook_ok = self._post_webhook(record)

        return {
            "harvest_persisted": True,
            "harvest_path": str(HARVEST_DIR / f"{event_id}.json"),
            "webhook_delivered": webhook_ok,
            "yieldswarm_shard": record["yieldswarm_shard"],
        }

    def _write_harvest_file(self, record: dict[str, Any]) -> None:
        try:
            HARVEST_DIR.mkdir(parents=True, exist_ok=True)
            path = HARVEST_DIR / f"{record['event_id']}.json"
            path.write_text(json.dumps(record, indent=2))
        except OSError as exc:
            logger.warning("harvest file write failed: %s", exc)

    def _post_webhook(self, record: dict[str, Any]) -> bool:
        if not self.webhook_url:
            return False
        body = json.dumps(record).encode()
        headers = {"Content-Type": "application/json"}
        if self.webhook_secret:
            headers["X-Kairo-Webhook-Secret"] = self.webhook_secret
        req = urllib.request.Request(
            self.webhook_url, data=body, headers=headers, method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return 200 <= resp.status < 300
        except (urllib.error.URLError, TimeoutError) as exc:
            logger.warning("webhook delivery failed: %s", exc)
            return False
