#!/usr/bin/env bash
# Carrizozo monitoring matrix — solar, Starlink, Z15 fleet, Tesla vehicles, edge nodes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:$PYTHONPATH}"

echo "=== YieldSwarm SWARM 1: Physical Core Monitor Matrix ==="
echo "Site: Carrizozo NM (10-acre sovereign data ranch)"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

python3 - <<'PY'
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))
from swarms.physical_core.engines.telemetry_engine import PhysicalCoreTelemetryEngine

engine = PhysicalCoreTelemetryEngine()
snap = engine.run_tick()

solar = snap["solar"]
conn = snap["connectivity"]
asics = snap["asics"]
vehicles = snap["vehicles"]
edge = snap["edge"]

print(f"Solar:     {solar['productionKw']} kW / {solar['arrayKwPeak']} kW peak [{solar['status']}]")
print(f"Starlink:  active={conn['activeLink']} primary={conn['primary']['status']} failover={conn['failover']['status']}")
print(f"ASICs:     {asics['aggregateHashrateGh']} GH/s aggregate ({asics['fleetSize']} Z15 Pro units)")
online_asics = sum(1 for u in asics["units"] if u["status"] == "mining")
print(f"           {online_asics} mining, {sum(1 for u in asics['units'] if u['status']=='offline')} offline")
print(f"Vehicles:  {len(vehicles)} Tesla samples")
for v in vehicles:
    k = v["kinematics"]
    m = v.get("mmorpgBridge", {})
    print(f"  - {v['vehicleId']}: {k['speedKmh']} km/h → {m.get('eventType')} (+{m.get('xpDelta')} XP)")
online_edge = sum(1 for n in edge["nodes"] if n["status"] == "online")
print(f"Edge:      {online_edge}/{len(edge['nodes'])} nodes online")

out = Path(".data/physical-core/latest.json")
print(f"\nSnapshot:  {out}")
print(json.dumps({"siteId": snap["siteId"], "capturedAt": snap["capturedAt"]}, indent=2))
PY

echo ""
echo "=== Monitor matrix complete ==="
