#!/usr/bin/env bash
# Run one helical heartbeat — rotates epoch across 4 swarms.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:$PYTHONPATH}"

python3 - <<'PY'
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))
from swarms.helical.bus import HelicalBus
from swarms.physical_core.engines.telemetry_engine import PhysicalCoreTelemetryEngine
from swarms.mining_pools.engines.pool_router import ingest_physical_core

bus = HelicalBus()
bus.register("physical-core", lambda _: PhysicalCoreTelemetryEngine().run_tick())
bus.register("mining-pools", lambda _: ingest_physical_core())
bus.register("marketplace", lambda _: {"schemaVersion": "marketplace/v1", "inventory": [], "orders": []})
bus.register("mmorpg", lambda _: {"schemaVersion": "mmorpg/v1", "worldEpoch": 0, "players": []})

envelope = bus.run_heartbeat()
print(json.dumps({"swarmId": envelope["swarmId"], "epoch": envelope["epoch"], "phase": envelope["phase"]}, indent=2))
PY
