#!/usr/bin/env bash
# Helium hotspot deployment helper
#
# Reads hotspot config from mining manager artifact or --config JSON.
# Does NOT store WiFi passwords in logs.
#
# Usage:
#   ./scripts/mining/deploy-helium-hotspot.sh
#   ./scripts/mining/deploy-helium-hotspot.sh --config .run/mining/helium-config.json
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="${REPO_ROOT}/.run/mining/helium-config.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "${CONFIG}" ]]; then
  echo "[helium] generating config via mining manager..."
  "${REPO_ROOT}/scripts/mining/mining-manager.sh" config >/dev/null
fi

if [[ ! -f "${CONFIG}" ]]; then
  echo "[helium] ERROR: no config at ${CONFIG}. Set DEPIN_HELIUM_HOTSPOT_KEYS." >&2
  exit 1
fi

python3 <<PY
import json
from pathlib import Path

cfg = json.loads(Path("${CONFIG}").read_text())
hotspots = cfg.get("hotspots", [])
print(f"[helium] deploying {len(hotspots)} hotspot(s)")
for i, h in enumerate(hotspots, 1):
    print(f"  [{i}] model={h.get('model')} serial={h.get('serial')} mac={h.get('mac')}")
    ssid = h.get("ssid")
    if ssid:
        print(f"      1. Connect phone to WiFi: {ssid}")
        print("      2. Open setup portal (192.168.4.1)")
        print(f"      3. Register serial {h.get('serial')} to Helium account")
        print("      4. Configure Ethernet/WiFi backhaul")
    wallet = h.get("wallet")
    if wallet:
        print(f"      payout wallet: {wallet}")
print("[helium] deployment checklist complete — confirm online in Helium app")
PY
