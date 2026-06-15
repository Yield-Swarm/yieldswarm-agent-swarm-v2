#!/usr/bin/env python3
"""Great Delta telemetry collector scaffold."""

from datetime import datetime, timezone
import json
import random
import time


def sample_event() -> dict:
    latency_ms = round(random.uniform(12.0, 79.5), 3)
    return {
        "stream": "great-delta",
        "event": "worker.heartbeat",
        "agentId": f"agent-{random.randint(1, 10080):05d}",
        "latencyMs": latency_ms,
        "within80msGuardrail": latency_ms <= 80,
        "treasurySplit": "50,30,15,5",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def main() -> None:
    while True:
        print(json.dumps(sample_event()))
        time.sleep(5)


if __name__ == "__main__":
    main()
