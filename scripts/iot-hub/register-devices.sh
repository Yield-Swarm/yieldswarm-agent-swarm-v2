#!/usr/bin/env bash
# Register all physical devices to the FWA_37KN9S-IoT network and swarm coordinator.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

export IOT_NETWORK_ID="${IOT_NETWORK_ID:-FWA_37KN9S-IoT}"
export IOT_HUB_DRY_RUN="${IOT_HUB_DRY_RUN:-1}"

log() { printf '[iot-register] %s\n' "$*" >&2; }

log "network=${IOT_NETWORK_ID}"
python3 services/iot_hub/cli.py register
