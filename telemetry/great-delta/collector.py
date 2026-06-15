#!/usr/bin/env python3
"""Great Delta telemetry collector — stdout + optional integration backend ingest."""

from __future__ import annotations

import json
import os
import random
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone


INGEST_URL = os.environ.get(
    "GREAT_DELTA_INGEST_URL",
    os.environ.get("YIELDSWARM_API_BASE", "http://127.0.0.1:8080/api") + "/great-delta/telemetry",
)


def sample_event() -> dict:
    latency_ms = round(random.uniform(12.0, 79.5), 3)
    return {
        "stream": "great-delta",
        "event": "worker.heartbeat",
        "agentId": f"agent-{random.randint(1, 10080):05d}",
        "latencyMs": latency_ms,
        "within80msGuardrail": latency_ms <= 80,
        "policy": "50/30/15/5",
        "splitBps": {
            "coreTreasury": 5000,
            "growthTreasury": 3000,
            "insuranceTreasury": 1500,
            "opsTreasury": 500,
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def post_event(event: dict) -> bool:
    if os.environ.get("GREAT_DELTA_INGEST_DISABLED", "").lower() in ("1", "true", "yes"):
        return False
    payload = json.dumps(
        {
            "event": event.get("event", "heartbeat"),
            "source": "collector",
            "sentAt": event.get("timestamp"),
            "agentId": event.get("agentId"),
            "latencyMs": event.get("latencyMs"),
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        INGEST_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return 200 <= resp.status < 300
    except (urllib.error.URLError, TimeoutError):
        return False


def main() -> None:
    while True:
        event = sample_event()
        print(json.dumps(event))
        post_event(event)
        time.sleep(5)


if __name__ == "__main__":
    main()
