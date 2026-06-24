#!/usr/bin/env bash
# Master multiminer hotload — local control plane + optional RunPod fleet
#
# Usage:
#   export KASPA_WALLET_ADDRESS=... MONERO_WALLET_ADDRESS=...
#   MINING_DRY_RUN=0 ./scripts/multiminer-hotload.sh
#   MULTIMINER_SKIP_RUNPOD=1 ./scripts/multiminer-hotload.sh   # local/API only
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
cd "${ROOT}"

log() { printf '[multiminer] %s\n' "$*"; }

# Vault injection if configured
if [[ -n "${VAULT_ADDR:-}" ]] && [[ -f scripts/vault-export-env.py ]]; then
  # shellcheck disable=SC1090
  eval "$(python3 scripts/vault-export-env.py mining 2>/dev/null || true)"
fi

log "=== Profitability intelligence ==="
python3 -m mining profitability --tier "${MINING_HARDWARE_TIER:-h100_sxm}" --json | head -c 1500
echo ""

log "=== Fleet hashpower estimates ==="
python3 -m mining hashpower --json
echo ""

log "=== Live benchmark (nvidia-smi if present) ==="
python3 -m mining benchmark --json 2>/dev/null || true
echo ""

log "=== Write miner configs ==="
python3 -m mining config --json

if [[ "${MINING_DRY_RUN:-1}" == "0" ]]; then
  log "=== Starting miners (kaspa + monero + qubic) ==="
  for m in kaspa qubic monero; do
    python3 -m mining start --miner "${m}" --json || log "WARN: ${m} start failed (wallet missing?)"
  done
else
  log "MINING_DRY_RUN=1 — skipping process spawn. Set MINING_DRY_RUN=0 to go live."
fi

if [[ "${MULTIMINER_SKIP_RUNPOD:-}" != "1" ]] && [[ -f scripts/runpod_fleet_deploy.sh ]]; then
  if [[ -n "${KASPA_WALLET_ADDRESS:-}" ]] && [[ -f "${RUNPOD_SSH_KEY:-${HOME}/.ssh/id_ed25519}" ]]; then
    log "=== RunPod fleet deploy ==="
    bash scripts/runpod_fleet_deploy.sh || log "WARN: RunPod deploy failed (SSH?)"
  else
    log "Skip RunPod — set KASPA_WALLET_ADDRESS + SSH key"
  fi
fi

log "=== Solenoid matrix pulse (API) ==="
if curl -sf http://127.0.0.1:8080/api/solenoid/status >/dev/null 2>&1; then
  curl -sf http://127.0.0.1:8080/api/solenoid/status | head -c 500
  echo ""
  curl -sf -X POST http://127.0.0.1:8080/api/solenoid/matrix -H 'Content-Type: application/json' -d '{}' | head -c 500
  echo ""
else
  log "Backend not up — start: cd backend && npm start"
fi

log "Hotload sequence complete."
