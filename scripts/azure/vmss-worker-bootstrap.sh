#!/usr/bin/env bash
# YieldSwarm VMSS worker bootstrap — injected as Azure VMSS customData.
# Sets fleet telemetry env vars, clones repo, starts integration backend in tmux.
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

GEOCRON_DATA="${GEOCRON_DATA:-GEOCRON_ALPHA_2026_STREAM}"
TELEMETRY_STREAM="${TELEMETRY_STREAM:-http://127.0.0.1:8080/api/telemetry}"
FLEET_API_KEY="${FLEET_API_KEY:-}"
HF_TOKEN="${HF_TOKEN:-}"
YIELDSWARM_REPO="${YIELDSWARM_REPO:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"
YIELDSWARM_BRANCH="${YIELDSWARM_BRANCH:-production}"
INSTALL_DIR="${INSTALL_DIR:-/opt/yieldswarm}"
VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"

log() { echo "[vmss-bootstrap] $*"; }

# --- System-wide env (Cursor / fleet ingest on login) -------------------------
cat >/etc/profile.d/yieldswarm_vmss.sh <<EOF
export GEOCRON_DATA='${GEOCRON_DATA}'
export TELEMETRY_STREAM='${TELEMETRY_STREAM}'
export FLEET_API_KEY='${FLEET_API_KEY}'
export HF_TOKEN='${HF_TOKEN}'
export AI_AGENT='1'
export CURSOR_AGENT='1'
export VAULT_ADDR='${VAULT_ADDR}'
export BACKEND_URL='http://127.0.0.1:8080'
export IOT_HUB_DRY_RUN='1'
export REWARDS_DRY_RUN='1'
EOF
chmod 644 /etc/profile.d/yieldswarm_vmss.sh
# shellcheck disable=SC1091
source /etc/profile.d/yieldswarm_vmss.sh

apt-get update -y
apt-get install -y git curl jq python3 python3-pip tmux

# --- Clone / update repo ------------------------------------------------------
mkdir -p "$(dirname "${INSTALL_DIR}")"
if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  git clone --depth 1 --branch "${YIELDSWARM_BRANCH}" "${YIELDSWARM_REPO}" "${INSTALL_DIR}"
else
  cd "${INSTALL_DIR}"
  git fetch origin "${YIELDSWARM_BRANCH}"
  git checkout "${YIELDSWARM_BRANCH}"
  git pull origin "${YIELDSWARM_BRANCH}" || true
fi
cd "${INSTALL_DIR}"

# --- Hugging Face agentic CLI + global skills ---------------------------------
if [[ -f scripts/fleet/install-hf-agent-skills.sh ]]; then
  chmod +x scripts/fleet/install-hf-agent-skills.sh
  HF_TOKEN="${HF_TOKEN}" ./scripts/fleet/install-hf-agent-skills.sh || log "WARN: HF skills install failed"
fi

# --- Node index from Azure instance metadata (optional fleet slot) ------------
IMDS="http://169.254.169.254/metadata/instance?api-version=2021-02-01"
META="$(curl -fsSL -H Metadata:true "${IMDS}" 2>/dev/null || echo '{}')"
VMSS_INDEX="$(echo "${META}" | jq -r '.compute.vmScaleSetName // empty')"
export FLEET_NODE_INDEX="${FLEET_NODE_INDEX:-8}"

# --- Backend in tmux ----------------------------------------------------------
if ! tmux has-session -t yieldswarm-backend 2>/dev/null; then
  tmux new-session -d -s yieldswarm-backend \
    "cd '${INSTALL_DIR}' && export PYTHONPATH='${INSTALL_DIR}' && node backend/src/server.js"
  log "started tmux session yieldswarm-backend"
fi

# --- Optional fleet provision (node 8 = Azure VMSS in .env.fleet.example) -------
if [[ -x ./swarm_provision.sh && -f ./.env.fleet ]]; then
  ./swarm_provision.sh "${FLEET_NODE_INDEX}" || log "WARN: swarm_provision failed"
fi

log "bootstrap complete — GEOCRON_DATA=${GEOCRON_DATA}"
