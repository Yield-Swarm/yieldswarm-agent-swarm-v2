#!/usr/bin/env bash
# Monitor device status on FWA_37KN9S-IoT (ICMP/HTTP/Helium adapters).
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

export IOT_NETWORK_ID="${IOT_NETWORK_ID:-FWA_37KN9S-IoT}"
export IOT_HUB_DRY_RUN="${IOT_HUB_DRY_RUN:-1}"
export IOT_PING_TIMEOUT_MS="${IOT_PING_TIMEOUT_MS:-1500}"
export IOT_PING_COUNT="${IOT_PING_COUNT:-2}"

DEVICE_ID="${1:-}"

if [[ -n "${DEVICE_ID}" ]]; then
  python3 services/iot_hub/cli.py device check "${DEVICE_ID}"
else
  python3 services/iot_hub/cli.py monitor
fi
