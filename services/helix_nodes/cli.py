#!/usr/bin/env python3
"""Helix Nodes CLI — register, heartbeat, lottery."""

from __future__ import annotations

import argparse
import json
import sys

from services.helix_nodes.store import get_store


def main() -> int:
    parser = argparse.ArgumentParser(description="Helix Nodes operator CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("summary")
    reg = sub.add_parser("register")
    reg.add_argument("--referral", default=None)
    hb = sub.add_parser("heartbeat")
    hb.add_argument("node_id")
    sub.add_parser("leaderboard")
    sub.add_parser("lottery")
    draw = sub.add_parser("draw")
    draw.add_argument("--confirm", action="store_true")

    args = parser.parse_args()
    store = get_store()

    if args.cmd == "summary":
        print(json.dumps(store.summary()))
    elif args.cmd == "register":
        print(json.dumps(store.register(referral_code=args.referral)))
    elif args.cmd == "heartbeat":
        out = store.heartbeat(args.node_id)
        if not out:
            print(json.dumps({"error": "node not found"}))
            return 1
        print(json.dumps(out))
    elif args.cmd == "leaderboard":
        print(json.dumps(store.leaderboard()))
    elif args.cmd == "lottery":
        print(json.dumps(store.lottery_current()))
    elif args.cmd == "draw":
        print(json.dumps(store.lottery_draw()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
