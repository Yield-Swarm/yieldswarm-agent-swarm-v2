#!/usr/bin/env bash
# Verify RunPod fleet mining sessions + GPU utilization
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
FLEET_JSON="${RUNPOD_FLEET_JSON:-${ROOT}/config/mining/runpod-fleet.json}"
SSH_KEY="${RUNPOD_SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_USER="${RUNPOD_SSH_USER:-root}"

log() { printf '[verify] %s\n' "$*"; }

PODS=()
if [[ -n "${RUNPOD_PODS:-}" ]]; then
  IFS=',' read -ra PODS <<< "${RUNPOD_PODS}"
elif [[ -f "${FLEET_JSON}" ]]; then
  mapfile -t PODS < <(python3 -c "
import json
for p in json.load(open('${FLEET_JSON}')).get('pods', []):
    print(p['id'])
")
fi

if [[ ${#PODS[@]} -eq 0 ]]; then
  log "No pods configured"
  exit 1
fi

echo "=== Local hashpower estimates ==="
python3 -m mining hashpower --json 2>/dev/null || true

echo ""
echo "=== Fleet remote status ==="
for POD in "${PODS[@]}"; do
  HOST="${SSH_USER}@${POD}@ssh.runpod.io"
  echo "--- ${POD} ---"
  ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
    -i "${SSH_KEY}" "${HOST}" \
    'screen -ls 2>/dev/null; echo; nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv 2>/dev/null || echo "no GPU"' \
    || log "UNREACHABLE (fix SSH pubkey)"
  echo ""
done

echo "=== Profitability top picks (H100) ==="
python3 -m mining profitability --tier h100_sxm --json 2>/dev/null | head -c 2000
echo ""
