#!/usr/bin/env bash
# RunPod Pod 0/1 — Nexus multi-mining activation (OpenClaw + unified mining manager).
#
# Usage (on RunPod after cloning repo):
#   export RUNPOD_POD_INDEX=0   # or 1
#   cp deploy/env/nexus-miner.env.example ~/.config/yieldswarm/nexus-miner.env
#   # edit nexus-miner.env with Vault-exported secrets — never commit
#   ./scripts/runpod/bootstrap-nexus-miner.sh
set -euo pipefail

log() { printf '[nexus-miner-bootstrap] %s\n' "$*" >&2; }

POD_INDEX="${RUNPOD_POD_INDEX:-0}"
OPENCLAW_ROOT="${OPENCLAW_POD_ROOT:-/opt/openclaw-pod-${POD_INDEX}}"
ALT_ROOTS=("claw-${POD_INDEX}" "${HOME}/claw-${POD_INDEX}" "${OPENCLAW_ROOT}")

# --- Load operator secrets (no hardcoded keys in this script) ---
for f in \
  "${HOME}/.config/yieldswarm/nexus-miner.env" \
  /etc/profile.d/yieldswarm_nexus_miner.sh \
  deploy/env/nexus-miner.env; do
  if [[ -f "${f}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${f}"
    set +a
    log "loaded ${f}"
    break
  fi
done

export EXECUTION_CAPACITY="${EXECUTION_CAPACITY:-0.80}"
export IOTEX_DEVICE_ID="${IOTEX_DEVICE_ID:-io_nexus_pebble_01}"
export IOTEX_W3BSTREAM_ENDPOINT="${IOTEX_W3BSTREAM_ENDPOINT:-https://w3bstream-mainnet.iotex.io/v1/projects/apollo_nexus}"
export SHADOW_CHAIN_ID="${SHADOW_CHAIN_ID:-shadow-solenoid-3}"
export MINING_DRY_RUN="${MINING_DRY_RUN:-0}"

# xAI / Grok — prefer GROK_API_KEY canonical name
if [[ -z "${XAI_API_KEY:-}" && -n "${GROK_API_KEY:-}" ]]; then
  export XAI_API_KEY="${GROK_API_KEY}"
fi

# --- Resolve workspace ---
REPO="${YIELDSWARM_REPO:-}"
if [[ -z "${REPO}" || ! -d "${REPO}/mining" ]]; then
  for root in "${ALT_ROOTS[@]}"; do
    if [[ -d "${root}/yieldswarm-agent-swarm-v2/mining" ]]; then
      REPO="${root}/yieldswarm-agent-swarm-v2"
      break
    fi
    if [[ -d "${root}/mining" ]]; then
      REPO="${root}"
      break
    fi
  done
fi

[[ -n "${REPO}" && -d "${REPO}/mining" ]] || {
  log "ERROR: repo not found — clone yieldswarm-agent-swarm-v2 to ${OPENCLAW_ROOT}"
  exit 1
}

cd "${REPO}"
log "repo=$(pwd) pod=${POD_INDEX} capacity=${EXECUTION_CAPACITY}"

# --- Optional OpenClaw daemon (Baseten background network) ---
if command -v pnpm >/dev/null 2>&1 && [[ -f package.json ]] && grep -q openclaw package.json 2>/dev/null; then
  pnpm openclaw onboard --install-daemon || log "WARN: openclaw onboard failed"
fi

# --- Fleet provision slot 7 = RunPod in .env.fleet.example ---
if [[ -x ./swarm_provision.sh && -f ./.env.fleet ]]; then
  ./swarm_provision.sh 7 || log "WARN: swarm_provision 7 failed"
fi

export PYTHONPATH="${REPO}${PYTHONPATH:+:${PYTHONPATH}}"
export MINING_RUN_DIR="${MINING_RUN_DIR:-${REPO}/.run/mining}"
mkdir -p "${MINING_RUN_DIR}"

log "starting mining manager (capacity=${EXECUTION_CAPACITY})..."
python3 -m mining start --capacity="${EXECUTION_CAPACITY}" --json || {
  log "WARN: mining start failed — check MINING_DRY_RUN and wallet env"
  exit 1
}

log "complete — gateway sync: POST ${NEXUS_GATEWAY_URL:-<set NEXUS_GATEWAY_URL>}/api/sync"
