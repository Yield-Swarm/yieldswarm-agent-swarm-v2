#!/usr/bin/env python3
"""Kairo → YieldSwarm Mandelbrot telemetry ingest bridge.

Receives signed telemetry events from the Kairo API and persists them into
the Odysseus ChromaDB memory mesh via agents.odysseus_memory.

Usage:
    python3 kairo/services/mandelbrot_ingest.py --watch http://localhost:3000
    python3 kairo/services/mandelbrot_ingest.py --event event.json
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any, Dict

# Allow imports from repo root.
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from agents.odysseus_memory import OdysseusMemory, build_agent_id  # noqa: E402
from kairo.lib.mandelbrot_route import route_event  # noqa: E402


def ingest_event(memory: OdysseusMemory, event: Dict[str, Any]) -> Dict[str, Any]:
    """Route a signed telemetry event into the ChromaDB mesh."""
    shard = route_event(event)
    agent_id = build_agent_id(shard["cron_shard"], shard["agent_index"])

    summary = json.dumps(
        {
            "source": "kairo",
            "driver_id": event.get("driverId"),
            "event_type": event.get("eventType"),
            "timestamp": event.get("timestamp"),
            "payload": event.get("payload"),
            "mandelbrot_shard": shard["global_index"],
            "tree_of_life": {
                "branch": shard["branch"],
                "tribe": shard["tribe"],
                "cron_shard": shard["cron_shard"],
            },
        },
        sort_keys=True,
    )
    doc_id = memory.record_cross_agent_learning(
        source_agent_id=agent_id,
        summary=summary,
        applies_to=[agent_id, f"kairo-driver:{event.get('driverId', '')}"],
        evidence={"mandelbrot_shard": shard["global_index"], "source": "kairo"},
    )

    return {"agent_id": agent_id, "doc_id": doc_id, "shard": shard}


def main() -> None:
    parser = argparse.ArgumentParser(description="Kairo Mandelbrot ingest bridge")
    parser.add_argument("--event", help="Path to a signed telemetry JSON file")
    parser.add_argument("--watch", help="Kairo API base URL to poll for events")
    parser.add_argument("--interval", type=int, default=30, help="Poll interval (seconds)")
    args = parser.parse_args()

    memory = OdysseusMemory()

    if args.event:
        event = json.loads(Path(args.event).read_text(encoding="utf-8"))
        result = ingest_event(memory, event)
        print(json.dumps(result, indent=2))
        return

    if args.watch:
        print(f"Watching {args.watch} for Kairo telemetry (interval={args.interval}s)")
        seen: set[str] = set()
        while True:
            try:
                import urllib.request

                req = urllib.request.Request(f"{args.watch}/api/kairo/drivers/register")
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode())
                for driver in data.get("drivers", []):
                    tid = driver["id"]
                    treq = urllib.request.Request(
                        f"{args.watch}/api/kairo/telemetry?driverId={tid}"
                    )
                    with urllib.request.urlopen(treq, timeout=10) as resp:
                        tdata = json.loads(resp.read().decode())
                    contrib = tdata.get("contribution", {})
                    key = f"{tid}:{contrib.get('lastEventAt', '')}"
                    if key not in seen and contrib.get("lastEventAt"):
                        seen.add(key)
                        print(f"Ingested contribution update for {driver['displayName']}")
            except Exception as exc:
                print(f"Poll error: {exc}", file=sys.stderr)
            time.sleep(args.interval)
        return

    parser.print_help()


if __name__ == "__main__":
    main()
