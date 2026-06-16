#!/usr/bin/env bash
# Vast.ai GPU burst provider (scaffold — requires VAST_API_KEY).
set -euo pipefail

VAST_API_KEY="${VAST_API_KEY:-}"
VAST_API="${VAST_API:-https://console.vast.ai/api/v0}"
GPU="${GPU:-RTX_4090}"

case "${1:-launch}" in
  launch)
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[dry-run] Vast launch GPU=${GPU}"
      exit 0
    fi
    if [[ -z "${VAST_API_KEY}" ]]; then
      echo "VAST_API_KEY not set — add to Vault: kv/yieldswarm/cloud/vast"
      echo "[scaffold] would search offers for GPU=${GPU} and create instance"
      exit 1
    fi
    # Search cheapest offer matching GPU
    OFFERS="$(curl -sfS "${VAST_API}/bundles/?q=%7B%22gpu_name%22%3A%7B%22eq%22%3A%22${GPU}%22%7D%7D" \
      -H "Authorization: Bearer ${VAST_API_KEY}" 2>/dev/null || echo '{}')"
    echo "Vast offers fetched — select offer and create instance via Vast console or API"
    echo "${OFFERS}" | jq '.offers[:3] // .' 2>/dev/null || echo "${OFFERS}"
    ;;
  teardown)
    echo "Vast teardown: destroy instances via Vast console or:"
    echo "  curl -X DELETE ${VAST_API}/instances/<id> -H 'Authorization: Bearer \$VAST_API_KEY'"
    ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac
