#!/usr/bin/env python3
"""Mining manager agent — sovereign loop tick."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from mining.manager import UnifiedMiningManager  # noqa: E402


def tick() -> None:
    mgr = UnifiedMiningManager()
    # Monitor only on tick — use MINING_AUTO_START=1 to auto-start stopped miners
    report = mgr.status()
    if os.getenv("MINING_AUTO_START", "").lower() in ("1", "true", "yes"):
        for name, st in report.get("miners", {}).items():
            if st.get("state") == "stopped":
                mgr.start(name)
        report = mgr.status()
    print(f"[mining] {report.get('running_count')}/{report.get('total')} running dry_run={report.get('dry_run')}")


def main() -> int:
    tick()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
