#!/usr/bin/env python3
"""
Export a single .env.fleet node row into shell exports for mining / IoT.

Usage:
  python3 scripts/fleet/fleet_export.py --node 0 --fleet .env.fleet
  eval "$(python3 scripts/fleet/fleet_export.py --node 1)"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict


def load_fleet(path: Path) -> Dict[str, str]:
    env: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        env[key.strip()] = val.strip().strip('"').strip("'")
    return env


def node_fields(env: Dict[str, str], index: int) -> Dict[str, str]:
    prefix = f"NODE_{index}_"
    return {k[len(prefix) :]: v for k, v in env.items() if k.startswith(prefix)}


def shell_quote(s: str) -> str:
    return "'" + s.replace("'", "'\"'\"'") + "'"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--node", type=int, required=True)
    parser.add_argument("--fleet", default=".env.fleet")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    fleet_path = Path(args.fleet)
    if not fleet_path.exists():
        print(f"echo 'fleet file missing: {fleet_path}'", file=sys.stderr)
        return 1

    env = load_fleet(fleet_path)
    row = node_fields(env, args.node)
    role = row.get("ROLE", "")
    wallet = row.get("WALLET") or env.get("FLEET_DEFAULT_WALLET", "")

    out: Dict[str, Any] = {
        "node_index": args.node,
        "role": role,
        "model": row.get("MODEL"),
        "serial": row.get("SERIAL"),
        "mac": row.get("MAC"),
        "platform": row.get("PLATFORM", "linux"),
    }

    if role in ("grass", "phone"):
        grass = [
            {
                "id": f"grass-node-{args.node}",
                "platform": row.get("PLATFORM", "android"),
                "wallet": wallet,
                "device_id": row.get("SERIAL", ""),
                "mac": row.get("MAC", ""),
            }
        ]
        out["GRASS_NODE_KEYS"] = grass
    elif role == "helium":
        helium = [
            {
                "model": row.get("MODEL", ""),
                "serial": row.get("SERIAL", ""),
                "mac": row.get("MAC", ""),
                "ssid": row.get("SSID", f"Helium-{row.get('MAC', '')[-4:].replace(':', '')}"),
                "wallet": wallet,
            }
        ]
        out["DEPIN_HELIUM_HOTSPOT_KEYS"] = helium
    elif role == "iotex":
        out["IOT_DEVICE"] = {
            "id": f"pebble-{args.node}",
            "model": row.get("MODEL"),
            "serial": row.get("SERIAL"),
            "mac": row.get("MAC"),
        }

    if args.json:
        print(json.dumps(out, indent=2))
        return 0

    lines = []
    if "GRASS_NODE_KEYS" in out:
        lines.append(f"export GRASS_NODE_KEYS={shell_quote(json.dumps(out['GRASS_NODE_KEYS']))}")
    if "DEPIN_HELIUM_HOTSPOT_KEYS" in out:
        lines.append(
            f"export DEPIN_HELIUM_HOTSPOT_KEYS={shell_quote(json.dumps(out['DEPIN_HELIUM_HOTSPOT_KEYS']))}"
        )
    if wallet:
        lines.append(f"export FLEET_NODE_WALLET={shell_quote(wallet)}")
    lines.append(f"export FLEET_NODE_INDEX={args.node}")
    lines.append(f"export FLEET_NODE_ROLE={shell_quote(role)}")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
