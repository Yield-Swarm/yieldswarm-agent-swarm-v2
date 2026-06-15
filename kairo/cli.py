#!/usr/bin/env python3
"""Kairo CLI — invoked by the backend adapter and deploy scripts."""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Allow running from repo root without package install.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from kairo.identity.wallet import register_driver
from kairo.telemetry.ingest import ingest_signed_event, list_contributions


def main() -> None:
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: kairo/cli.py <command> [args]"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "ping":
        print(json.dumps({"ok": True}))
        return

    if cmd == "register":
        fp = sys.argv[2] if len(sys.argv) > 2 else None
        identity = register_driver(device_fingerprint=fp)
        print(json.dumps(identity.to_dict()))
        return

    if cmd == "ingest":
        raw = json.loads(sys.argv[2])
        event, err = ingest_signed_event(raw)
        if err:
            print(json.dumps({"ok": False, "error": err}))
            sys.exit(1)
        print(json.dumps({"ok": True, "event": event.to_dict() if event else None}))
        return

    if cmd == "contributions":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        items = [c.to_dict() for c in list_contributions(limit)]
        print(json.dumps({"contributions": items}))
        return

    print(json.dumps({"error": f"unknown command: {cmd}"}))
    sys.exit(1)


if __name__ == "__main__":
    main()
