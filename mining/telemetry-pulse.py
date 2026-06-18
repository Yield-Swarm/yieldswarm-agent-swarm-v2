#!/usr/bin/env python3
"""Push mining telemetry into Helix Entropy Core (Pillar 5 + 7) via CommonJS bridge."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))


def main() -> None:
    raw = sys.stdin.read().strip()
    if not raw:
        return
    payload = json.loads(raw)

    # Node bridge for HardenedAuditEngine + SymbioticEvolutionEngine
    bridge = REPO / "mining" / "helix-ingest.js"
    if bridge.exists():
        import subprocess

        subprocess.run(
            ["node", str(bridge)],
            input=raw.encode(),
            check=False,
            env={**os.environ, "NODE_PATH": str(REPO)},
        )
        return

    # Fallback: append to local ancestral log
    log_path = Path(os.environ.get("MINING_ANCESTRAL_LOG", ".run/mining-ancestral.jsonl"))
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"ingested": True, **payload}) + "\n")


if __name__ == "__main__":
    main()
