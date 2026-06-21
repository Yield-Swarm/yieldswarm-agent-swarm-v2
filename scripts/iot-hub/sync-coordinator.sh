#!/usr/bin/env bash
# Full monitor sweep + push to Nexus messaging bus and sovereign dashboard overlay.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

export IOT_NETWORK_ID="${IOT_NETWORK_ID:-FWA_37KN9S-IoT}"
export IOT_HUB_DRY_RUN="${IOT_HUB_DRY_RUN:-1}"

log() { printf '[iot-sync] %s\n' "$*" >&2; }

log "syncing IoT hub → swarm coordinator (Nexus bus)"
python3 services/iot_hub/cli.py sync
