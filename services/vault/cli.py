"""Vault injection CLI — list dynamic secret injection targets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from services.vault.injection import injection_spec, list_injection_targets, template_for_provider


def main() -> int:
    p = argparse.ArgumentParser(description="Vault dynamic secret injection")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list")
    spec = sub.add_parser("spec")
    spec.add_argument("provider")
    spec.add_argument("solenoid")
    tpl = sub.add_parser("template")
    tpl.add_argument("provider")

    args = p.parse_args()
    if args.cmd == "list":
        print(json.dumps({"targets": list_injection_targets()}))
    elif args.cmd == "spec":
        print(json.dumps(injection_spec(args.provider, args.solenoid)))
    elif args.cmd == "template":
        path = template_for_provider(args.provider)
        print(path.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
