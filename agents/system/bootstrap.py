"""Bootstrap helper to materialize manifests and optionally run API."""

from __future__ import annotations

import argparse
from pathlib import Path

from agents.system.deity_manifests import ensure_deity_manifests
from agents.system.leaderboard_api import run_server


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap Arena agent system")
    parser.add_argument("--root-dir", default="/workspace/agents")
    parser.add_argument("--generate-only", action="store_true")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8420)
    args = parser.parse_args()

    root_dir = Path(args.root_dir)
    changed = ensure_deity_manifests(root_dir)
    print(f"deity manifests ensured: {len(changed)} file(s) changed")
    if args.generate_only:
        return
    run_server(host=args.host, port=args.port, root_dir=root_dir)


if __name__ == "__main__":
    main()
