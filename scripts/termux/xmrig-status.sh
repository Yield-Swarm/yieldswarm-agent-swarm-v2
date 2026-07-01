#!/usr/bin/env bash
# Aggregate XMRig hashrate across 8 Termux HTTP API ports → JSON state file.
#
# Usage:
#   ./scripts/termux/xmrig-status.sh
#   ./scripts/termux/xmrig-status.sh --prometheus
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTANCES="${XMRIG_INSTANCES:-8}"
PORT_BASE="${XMRIG_HTTP_PORT_BASE:-8081}"
STATE_DIR="${REPO_ROOT}/.data/termux-xmrig"
OUT_JSON="${STATE_DIR}/latest.json"
PROM="${1:-}"

mkdir -p "${STATE_DIR}"

python3 - "${INSTANCES}" "${PORT_BASE}" "${OUT_JSON}" "${PROM}" <<'PY'
import json, sys, urllib.request
from datetime import datetime, timezone

instances = int(sys.argv[1])
port_base = int(sys.argv[2])
out_path = sys.argv[3]
prom = sys.argv[4] == "--prometheus"

rows = []
total_hps = 0.0
alive = 0

for i in range(1, instances + 1):
    port = port_base + i - 1
    url = f"http://127.0.0.1:{port}/1/summary"
    row = {"instance": i, "port": port, "worker": f"TPIT-TERMUX-{i:02d}", "alive": False, "hashrateHps": 0}
    try:
        with urllib.request.urlopen(url, timeout=2) as resp:
            data = json.loads(resp.read().decode())
        hr = data.get("hashrate", {}).get("total", [0])
        hps = float(hr[0]) if hr else 0.0
        row["alive"] = hps > 0 or data.get("connection", {}).get("uptime", 0) > 0
        row["hashrateHps"] = hps
        row["worker"] = data.get("connection", {}).get("rig_id") or row["worker"]
        row["uptime"] = data.get("connection", {}).get("uptime", 0)
        if row["alive"]:
            alive += 1
        total_hps += hps
    except Exception as exc:
        row["error"] = str(exc)
    rows.append(row)

state = {
    "schemaVersion": "termux-xmrig/v1",
    "capturedAt": datetime.now(timezone.utc).isoformat(),
    "platform": "termux-android",
    "instances": instances,
    "instancesAlive": alive,
    "hashrateTotalHps": round(total_hps, 2),
    "hashrateTotalKhps": round(total_hps / 1000, 3),
    "workers": rows,
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2)

if prom:
    print("# HELP termux_xmrig_hashrate_hps Total XMRig hashrate across Termux instances")
    print("# TYPE termux_xmrig_hashrate_hps gauge")
    print(f"termux_xmrig_hashrate_hps {total_hps}")
    print("# HELP termux_xmrig_instances_alive Number of alive XMRig HTTP endpoints")
    print("# TYPE termux_xmrig_instances_alive gauge")
    print(f"termux_xmrig_instances_alive {alive}")
    for r in rows:
        labels = f'instance="{r["instance"]}",port="{r["port"]}"'
        print(f'termux_xmrig_instance_hashrate_hps{{{labels}}} {r["hashrateHps"]}')
else:
    print(json.dumps(state, indent=2))
PY
