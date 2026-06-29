"""Marketing circuit-breaker — pause ad crons when RPC or pool endpoints fail."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class MarketingCircuitBreaker:
    """Trips on RPC/pool failure; pings ad network pause webhooks."""

    def __init__(self) -> None:
        self.budget_usd = float(os.environ.get("MARKETING_CRON_BUDGET_USD", "64000"))
        self.monthly_buffer = float(os.environ.get("MARKETING_CASH_BUFFER_USD", "8000"))
        self.enabled = os.environ.get("MARKETING_CIRCUIT_BREAKER_ENABLED", "true").lower() in (
            "1",
            "true",
            "yes",
        )
        self.webhooks = {
            "x": os.environ.get("MARKETING_WEBHOOK_X", ""),
            "meta": os.environ.get("MARKETING_WEBHOOK_META", ""),
            "google": os.environ.get("MARKETING_WEBHOOK_GOOGLE", ""),
            "tiktok": os.environ.get("MARKETING_WEBHOOK_TIKTOK", ""),
        }
        self.rpc_urls = {
            "solana": os.environ.get("ALCHEMY_SOLANA_RPC_URL", os.environ.get("SOLANA_RPC_URL", "")),
            "ethereum": os.environ.get("ALCHEMY_ETH_RPC_URL", os.environ.get("ETHEREUM_RPC_URL", "")),
        }
        self._tripped = False
        self._last_trip_reason: str | None = None

    def _probe_rpc(self, url: str) -> bool:
        if not url:
            return False
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "getHealth"}).encode()
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read().decode())
                return "error" not in data
        except (urllib.error.URLError, json.JSONDecodeError, OSError, TimeoutError):
            try:
                body2 = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
                req2 = urllib.request.Request(url, data=body2, headers={"Content-Type": "application/json"}, method="POST")
                with urllib.request.urlopen(req2, timeout=8) as resp2:
                    return resp2.status == 200
            except (urllib.error.URLError, OSError, TimeoutError):
                return False

    def _fire_webhook(self, platform: str, url: str, payload: dict[str, Any]) -> bool:
        if not url:
            return False
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return 200 <= resp.status < 300
        except (urllib.error.URLError, OSError):
            return False

    def check_health(self, pool_state: dict[str, Any] | None = None) -> dict[str, Any]:
        rpc_status = {name: self._probe_rpc(url) for name, url in self.rpc_urls.items()}
        pool_ok = True
        if pool_state:
            pool_ok = bool(pool_state.get("activeNetwork"))

        healthy = all(rpc_status.values()) and pool_ok
        if not healthy and self.enabled and not self._tripped:
            reason = []
            if not all(rpc_status.values()):
                reason.append("rpc_degraded")
            if not pool_ok:
                reason.append("pool_disconnect")
            self.trip(";".join(reason))

        return {
            "schemaVersion": "marketing-circuit-breaker/v1",
            "capturedAt": _utc_now(),
            "healthy": healthy,
            "tripped": self._tripped,
            "tripReason": self._last_trip_reason,
            "rpcStatus": rpc_status,
            "budgetUsd": self.budget_usd,
            "cashBufferUsd": self.monthly_buffer,
        }

    def trip(self, reason: str) -> dict[str, Any]:
        self._tripped = True
        self._last_trip_reason = reason
        payload = {
            "action": "pause_campaigns",
            "reason": reason,
            "budgetProtectedUsd": self.budget_usd,
            "timestamp": _utc_now(),
        }
        results = {
            platform: self._fire_webhook(platform, url, payload)
            for platform, url in self.webhooks.items()
        }
        return {"tripped": True, "reason": reason, "webhookResults": results}

    def reset(self) -> None:
        self._tripped = False
        self._last_trip_reason = None
