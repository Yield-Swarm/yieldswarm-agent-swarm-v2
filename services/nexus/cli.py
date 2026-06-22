#!/usr/bin/env python3
"""Nexus Chain CLI — status, registry, messaging, multicloud."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from services.nexus.orchestrator import NexusOrchestrator
from services.nexus.registry import SolenoidRegistry
from services.nexus.messaging import MessagingBus
from services.nexus.multicloud import MultiCloudManager


def main() -> int:
    p = argparse.ArgumentParser(description="Nexus Chain orchestrator")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status")
    sub.add_parser("solenoids")

    reg = sub.add_parser("register-agent")
    reg.add_argument("agent_id")
    reg.add_argument("solenoid")
    reg.add_argument("shard_id", type=int)

    disp = sub.add_parser("dispatch")
    disp.add_argument("target")
    disp.add_argument("topic")
    disp.add_argument("payload", default="{}")

    mc = sub.add_parser("multicloud")
    mc_sub = mc.add_subparsers(dest="mc_cmd", required=True)
    launch = mc_sub.add_parser("launch")
    launch.add_argument("provider")
    launch.add_argument("workload", nargs="?", default="gpu-worker")

    args = p.parse_args()
    orch = NexusOrchestrator()

    if args.cmd == "status":
        print(json.dumps(orch.status()))
    elif args.cmd == "solenoids":
        print(json.dumps({"solenoids": [s.to_dict() for s in orch.registry.list_solenoids()]}))
    elif args.cmd == "register-agent":
        slot = orch.registry.register_agent(args.agent_id, args.solenoid, args.shard_id)
        print(json.dumps({"ok": True, "agent": slot.__dict__}))
    elif args.cmd == "dispatch":
        payload = json.loads(args.payload) if args.payload else {}
        print(json.dumps(orch.dispatch(args.target, args.topic, payload)))
    elif args.cmd == "multicloud" and args.mc_cmd == "launch":
        print(json.dumps(orch.multicloud.launch(args.provider, args.workload)))
    else:
        print(json.dumps({"error": "unknown command"}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
