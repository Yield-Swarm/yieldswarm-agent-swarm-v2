#!/usr/bin/env python3
"""IoT Hub CLI — register devices, monitor status, sync coordinator."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from services.iot_hub.orchestrator import IoTHubOrchestrator


def main() -> int:
    p = argparse.ArgumentParser(description="IoT Hub — FWA_37KN9S-IoT device management")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status")
    sub.add_parser("register")
    sub.add_parser("monitor")
    sub.add_parser("sync")

    dev = sub.add_parser("device")
    dev_sub = dev.add_subparsers(dest="dev_cmd", required=True)
    dev_sub.add_parser("list")
    check = dev_sub.add_parser("check")
    check.add_argument("device_id")

    args = p.parse_args()
    hub = IoTHubOrchestrator()

    if args.cmd == "status":
        print(json.dumps(hub.status()))
    elif args.cmd == "register":
        print(json.dumps(hub.register_network()))
    elif args.cmd == "monitor":
        print(json.dumps(hub.monitor.check_all()))
    elif args.cmd == "sync":
        print(json.dumps(hub.monitor_and_sync()))
    elif args.cmd == "device" and args.dev_cmd == "list":
        print(json.dumps({"devices": [d.to_dict() for d in hub.registry.list_devices()]}))
    elif args.cmd == "device" and args.dev_cmd == "check":
        print(json.dumps(hub.monitor.check_device(args.device_id)))
    else:
        print(json.dumps({"error": "unknown command"}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
