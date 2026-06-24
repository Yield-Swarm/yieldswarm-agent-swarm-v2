#!/usr/bin/env bash
# Hotload 16 Kimi Claw workers — secrets from Vault/env ONLY (never hardcoded)
#
# Prerequisites:
#   1. SSH keys injected on each RunPod pod (see docs/RUNPOD_SSH_SETUP.md)
#   2. export VAULT_ADDR + VAULT_TOKEN OR populate .env with AWS_* / worker keys
#   3. KIMI_CLAW_HOSTS file with one pod id per line
#
# Usage:
#   export KIMI_CLAW_HOSTS_FILE=config/mining/kimi-claw-hosts.example.txt
#   ./scripts/hotload-kimi-claws.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
HOSTS_FILE="${KIMI_CLAW_HOSTS_FILE:-${ROOT}/config/mining/kimi-claw-hosts.example.txt}"
SSH_KEY="${RUNPOD_SSH_KEY:-${HOME}/.ssh/id_ed25519}"
SSH_USER="${RUNPOD_SSH_USER:-root}"
LOG_DIR="${ROOT}/.run/kimi-claw-hotload"
mkdir -p "${LOG_DIR}"

log() { printf '[kimi-claw] %s\n' "$*"; }

if [[ ! -f "${HOSTS_FILE}" ]]; then
  log "ERROR: hosts file missing: ${HOSTS_FILE}"
  exit 1
fi

# Load secrets from Vault if available
if [[ -n "${VAULT_ADDR:-}" ]] && [[ -f "${ROOT}/scripts/vault-export-env.py" ]]; then
  # shellcheck disable=SC1090
  eval "$(python3 "${ROOT}/scripts/vault-export-env.py" mining 2>/dev/null || true)"
fi

if [[ ! -f "${SSH_KEY}" ]]; then
  log "ERROR: SSH key missing: ${SSH_KEY}"
  exit 1
fi

INDEX=0
while IFS= read -r POD || [[ -n "${POD}" ]]; do
  [[ -z "${POD}" || "${POD}" =~ ^# ]] && continue
  HOST="${SSH_USER}@${POD}@ssh.runpod.io"
  log "Wiring node ${INDEX}: ${POD}"

  ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new \
    -i "${SSH_KEY}" "${HOST}" bash -s <<REMOTE || log "WARN: failed ${POD}"
set -euo pipefail
export WORKER_ID="kimi_claw_node_${INDEX}"
export CLUSTER_NAME="kimi-swarm"
export EXECUTION_CAPACITY="${EXECUTION_CAPACITY:-0.80}"

mkdir -p ~/.kimi_swarm ~/yieldswarm-logs
# Secrets injected at runtime from orchestrator env — never write to disk in git
if [[ -n "\${AWS_ACCESS_KEY_ID:-}" ]]; then
  cat > ~/.kimi_swarm/secrets.env <<EOF
export AWS_ACCESS_KEY_ID="\${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="\${AWS_SECRET_ACCESS_KEY}"
export WORKER_ID="${WORKER_ID}"
export CLUSTER_NAME="${CLUSTER_NAME}"
EOF
  chmod 600 ~/.kimi_swarm/secrets.env
fi

REPO="\${HOME}/openclaw-pod-\${INDEX}"
if [[ ! -d "\${REPO}" ]]; then
  git clone https://github.com/basetenlabs/openclaw-baseten.git "\${REPO}" 2>/dev/null || true
fi
cd "\${REPO}" 2>/dev/null || exit 0

if command -v pnpm >/dev/null 2>&1; then
  pnpm install --no-frozen-lockfile 2>/dev/null || true
  pnpm build 2>/dev/null || true
fi

pkill -f 'openclaw onboard' 2>/dev/null || true
screen -dmS "kimi_claw_\${INDEX}" bash -c '
  source ~/.kimi_swarm/secrets.env 2>/dev/null || true
  pnpm openclaw onboard --install-daemon 2>&1 | tee -a ~/yieldswarm-logs/kimi-'"${INDEX}"'.log
'
echo "OK node ${INDEX}"
REMOTE

  INDEX=$((INDEX + 1))
done < "${HOSTS_FILE}"

log "Hotload complete for ${INDEX} nodes. Logs: ${LOG_DIR}"
