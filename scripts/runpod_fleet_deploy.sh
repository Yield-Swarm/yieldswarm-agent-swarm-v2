#!/usr/bin/env bash
# RunPod fleet multiminer hotload — KAS (GPU) + XMR (CPU) + optional Qubic
#
# NO secrets in this file. Set wallets via env or Vault before running:
#   export KASPA_WALLET_ADDRESS=...
#   export QUBIC_WALLET_ADDRESS=...
#   export MONERO_WALLET_ADDRESS=...
#   export RUNPOD_SSH_KEY=~/.ssh/id_ed25519
#
# Usage:
#   ./scripts/runpod_fleet_deploy.sh
#   RUNPOD_PODS="pod1@ssh.runpod.io,pod2@ssh.runpod.io" ./scripts/runpod_fleet_deploy.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
FLEET_JSON="${RUNPOD_FLEET_JSON:-${ROOT}/config/mining/runpod-fleet.json}"
SSH_KEY="${RUNPOD_SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_USER="${RUNPOD_SSH_USER:-root}"
LOG_LOCAL="${ROOT}/.run/runpod-fleet-deploy.log"

mkdir -p "${ROOT}/.run"
exec > >(tee -a "${LOG_LOCAL}") 2>&1

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*"; }

require_wallet() {
  local name="$1" val="$2"
  if [[ -z "${val}" ]]; then
    log "ERROR: ${name} not set — export before deploy"
    exit 1
  fi
}

KASPA_WALLET="${KASPA_WALLET_ADDRESS:-${KAS_WALLET_ADDRESS:-}}"
QUBIC_WALLET="${QUBIC_WALLET_ADDRESS:-${QUBIC_WALLET:-}}"
XMR_WALLET="${MONERO_WALLET_ADDRESS:-${XMR_WALLET_ADDRESS:-}}"

require_wallet "KASPA_WALLET_ADDRESS" "${KASPA_WALLET}"
require_wallet "MONERO_WALLET_ADDRESS" "${XMR_WALLET}"

if [[ ! -f "${SSH_KEY}" ]]; then
  log "ERROR: SSH key not found: ${SSH_KEY}"
  log "Run: ssh-keygen -t ed25519 -f ${SSH_KEY}"
  log "Then paste $(cat "${SSH_KEY}.pub" 2>/dev/null || echo '<pubkey>') into RunPod web terminal authorized_keys"
  exit 1
fi

# Build pod list from env or JSON
PODS=()
if [[ -n "${RUNPOD_PODS:-}" ]]; then
  IFS=',' read -ra PODS <<< "${RUNPOD_PODS}"
else
  if command -v python3 >/dev/null 2>&1 && [[ -f "${FLEET_JSON}" ]]; then
    mapfile -t PODS < <(python3 -c "
import json, sys
data = json.load(open('${FLEET_JSON}'))
for p in data.get('pods', []):
    print(p['id'])
")
  fi
fi

if [[ ${#PODS[@]} -eq 0 ]]; then
  log "ERROR: no pods — set RUNPOD_PODS or config/mining/runpod-fleet.json"
  exit 1
fi

log "Deploying multiminer to ${#PODS[@]} RunPod instance(s)"

REMOTE_SCRIPT=$(cat <<'REMOTE'
set -euo pipefail
LOG_DIR="${HOME}/yieldswarm-logs"
mkdir -p "${LOG_DIR}" "${HOME}/multiminer"
cd "${HOME}/multiminer"

pkill -f SRBMiner-MULTI 2>/dev/null || true
pkill -f xmrig 2>/dev/null || true
pkill -f qubic 2>/dev/null || true
sleep 1

if ! command -v screen >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y screen curl jq
fi

# SRBMiner for kHeavyHash (Kaspa)
if [[ ! -x ./SRBMiner-MULTI ]]; then
  echo "Downloading SRBMiner-MULTI..."
  curl -fsSL -o srb.tar.xz "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.6.0/SRBMiner-Multi-2-6-0-Linux.tar.xz"
  tar -xf srb.tar.xz --strip-components=1 && rm -f srb.tar.xz
  chmod +x ./SRBMiner-MULTI 2>/dev/null || true
fi

# xmrig for RandomX (CPU)
if ! command -v xmrig >/dev/null 2>&1 && [[ ! -x ./xmrig ]]; then
  echo "Downloading xmrig..."
  curl -fsSL -o xmrig.tar.gz "https://github.com/xmrig/xmrig/releases/download/v6.21.2/xmrig-6.21.2-linux-x64.tar.gz"
  tar -xzf xmrig.tar.gz --strip-components=1 && rm -f xmrig.tar.gz
  chmod +x ./xmrig 2>/dev/null || true
fi

XMRIG_BIN="xmrig"
command -v xmrig >/dev/null 2>&1 || XMRIG_BIN="./xmrig"

CPU_CORES=$(nproc)
MINING_THREADS=$((CPU_CORES > 2 ? CPU_CORES - 2 : 1))
WORKER_SUFFIX="${POD_SUFFIX:-worker}"

echo "GPU: Kaspa kHeavyHash -> ${KASPA_WALLET}"
screen -dmS gpu_kaspa bash -c "./SRBMiner-MULTI --algorithm kheavyhash --pool kas.auto.nicehash.com:3385 --wallet ${KASPA_WALLET}.${WORKER_SUFFIX} 2>&1 | tee -a ${LOG_DIR}/kaspa.log"

echo "CPU: Monero RandomX -> pool"
screen -dmS cpu_xmr bash -c "${XMRIG_BIN} -o gulf.moneroocean.stream:10128 -u ${XMR_WALLET} -p x -t ${MINING_THREADS} 2>&1 | tee -a ${LOG_DIR}/xmr.log"

if [[ -n "${QUBIC_WALLET:-}" ]] && command -v qubic-cli >/dev/null 2>&1; then
  screen -dmS gpu_qubic bash -c "qubic-cli mine --wallet ${QUBIC_WALLET} 2>&1 | tee -a ${LOG_DIR}/qubic.log"
fi

sleep 2
screen -ls | tee "${LOG_DIR}/screens.txt"
nvidia-smi 2>/dev/null | tee "${LOG_DIR}/nvidia-smi.txt" || echo "no nvidia-smi"
echo "DEPLOY_OK"
REMOTE
)

for POD in "${PODS[@]}"; do
  HOST="${SSH_USER}@${POD}@ssh.runpod.io"
  SUFFIX="${POD%%-*}"
  log "Hotloading ${HOST} (suffix=${SUFFIX})"

  if ! ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
      -i "${SSH_KEY}" "${HOST}" \
      "KASPA_WALLET='${KASPA_WALLET}' XMR_WALLET='${XMR_WALLET}' QUBIC_WALLET='${QUBIC_WALLET}' POD_SUFFIX='${SUFFIX}' bash -s" <<< "${REMOTE_SCRIPT}"; then
    log "WARN: SSH failed for ${POD} — inject pubkey via RunPod web terminal"
  fi
done

log "Fleet deploy complete. Verify: ./scripts/runpod_fleet_verify.sh"
