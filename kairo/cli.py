#!/usr/bin/env python3
"""Kairo CLI — invoked by the backend adapter and deploy scripts."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def main() -> None:
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: kairo/cli.py <command> [args]"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "ping":
        print(json.dumps({"ok": True}))
        return

    if cmd == "register":
        from kairo.identity.wallet import register_driver
        fp = sys.argv[2] if len(sys.argv) > 2 else None
        identity = register_driver(device_fingerprint=fp)
        print(json.dumps(identity.to_public_dict()))
        return

    if cmd == "ingest":
        from kairo.telemetry.ingest import ingest_signed_event
        raw = json.loads(sys.argv[2])
        event, err = ingest_signed_event(raw)
        if err:
            print(json.dumps({"ok": False, "error": err}))
            sys.exit(1)
        print(json.dumps({"ok": True, "event": event}))
        return

    if cmd == "contributions":
        from kairo.services.mandelbrot_pipeline import MandelbrotPipeline
        from pathlib import Path as P
        pipeline = MandelbrotPipeline(P(__file__).resolve().parent / "data" / "pipeline")
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        items = []
        for driver_id in list(pipeline._contributions.keys())[:limit]:
            stats = pipeline.driver_stats(driver_id)
            if stats:
                items.append(stats)
        print(json.dumps({"contributions": items}))
        return

    print(json.dumps({"error": f"unknown command: {cmd}"}))
    sys.exit(1)


if __name__ == "__main__":
    main()
