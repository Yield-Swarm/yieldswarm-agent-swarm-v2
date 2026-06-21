#!/usr/bin/env python3
"""
Pin Bifröst bridge library paths and version lock for reproducible deploys.

Usage:
  python3 scripts/bifrost_pin.py [--dry-run] [--lib-dir PATH] [--lock-file PATH]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def pin_libraries(
    lib_dir: Path,
    lock_file: Path,
    dry_run: bool = False,
) -> dict:
    """Record pinned lib paths and bridge script checksum metadata."""
    bridge_script = repo_root() / "scripts" / "bifrost-bridge.sh"
    lib_bifrost = lib_dir / "bifrost.sh"

    entries = {
        "pinned_at": datetime.now(timezone.utc).isoformat(),
        "lib_dir": str(lib_dir.resolve()),
        "files": {},
    }

    for path in (lib_bifrost, bridge_script):
        if path.is_file():
            entries["files"][path.name] = {
                "path": str(path.resolve()),
                "size_bytes": path.stat().st_size,
                "executable": os.access(path, os.X_OK),
            }

    if dry_run:
        print(json.dumps({"dry_run": True, "would_write": str(lock_file), **entries}, indent=2))
        return entries

    lock_file.parent.mkdir(parents=True, exist_ok=True)
    lock_file.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "lock_file": str(lock_file), **entries}, indent=2))
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description="Pin Bifröst bridge library paths")
    parser.add_argument(
        "--lib-dir",
        default=str(repo_root() / "scripts" / "lib"),
        help="Directory containing bifrost.sh helpers",
    )
    parser.add_argument(
        "--lock-file",
        default=str(repo_root() / ".run" / "bifrost" / "pin.lock.json"),
        help="Output lock file path",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be pinned without writing lock file",
    )
    args = parser.parse_args()

    lib_dir = Path(args.lib_dir)
    lock_file = Path(args.lock_file)

    if not lib_dir.is_dir():
        print(f"ERROR: lib directory does not exist: {lib_dir}", file=sys.stderr)
        return 1

    pin_libraries(lib_dir, lock_file, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
