#!/usr/bin/env bash
# edge_gateway_normalizer.sh — Local hub ingestion + Pebble coordinate normalization
#
# Interweaves: Local gateway (192.168.1.158) → IoT Hub registry + Solenoid edge SDK
#
# Usage (Termux / local hub):
#   cd ~/yieldswarm-agent-swarm-v2
#   ./scripts/edge/edge_gateway_normalizer.sh
#
# Env:
#   YIELDSWARM_REPO, IOT_EDGE_SOURCE, IOT_PEBBLE_DEVICE_ID, IOT_RAW_PACKET_JSON
set -euo pipefail

REPO_ROOT="${YIELDSWARM_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOG_DIR="${YIELDSWARM_LOG_DIR:-$HOME/yieldswarm-logs}"
EDGE_SOURCE="${IOT_EDGE_SOURCE:-192.168.1.158}"
DEVICE_ID="${IOT_PEBBLE_DEVICE_ID:-io_nexus_pebble_01}"
OUT_DIR="${REPO_ROOT}/.run/iot-edge"
OUT_FILE="${OUT_DIR}/normalized_edge_payload.json"

log() { printf '[edge-gateway] %s\n' "$*" >&2; }

[[ -d "${REPO_ROOT}/services/iot_hub" ]] || {
  log "ERROR: repo not found at ${REPO_ROOT}"
  exit 1
}

mkdir -p "${LOG_DIR}" "${OUT_DIR}"
cd "${REPO_ROOT}"

log "Task 1 — mapping fleet matrix, bootstrapping edge normalizer (source=${EDGE_SOURCE})"

export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
python3 - "${OUT_FILE}" "${EDGE_SOURCE}" "${DEVICE_ID}" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

from services.iot_hub.pebble_coords import normalize_pebble_packet

out_file, edge_source, device_id = sys.argv[1:4]

raw_json = os.environ.get("IOT_RAW_PACKET_JSON", "")
if raw_json.strip():
    packet = json.loads(raw_json)
else:
    packet = {
        "snr": 14.2,
        "vbat": 3700,
        "latitude": 3050.69225,
        "longitude": 11448.65815,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

payload = normalize_pebble_packet(
    packet,
    device_identity=device_id,
    edge_source=edge_source,
)

with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)

lat = payload["telemetry"]["latitude_dd"]
lon = payload["telemetry"]["longitude_dd"]
print(f"OK lat_dd={lat} lon_dd={lon} -> {out_file}")
PY

# Register with IoT Hub coordinator when available
if [[ -x scripts/iot-hub/sync-coordinator.sh ]]; then
  scripts/iot-hub/sync-coordinator.sh >>"${LOG_DIR}/edge_ingestion.log" 2>&1 || \
    log "WARN: iot-hub sync skipped"
fi

log "complete — payload at ${OUT_FILE}"
