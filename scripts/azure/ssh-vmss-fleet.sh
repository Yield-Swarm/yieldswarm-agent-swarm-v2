#!/usr/bin/env bash
# =============================================================================
# ssh-vmss-fleet.sh — SSH into every VMSS instance via inbound NAT rules
#
# Usage:
#   ./scripts/azure/ssh-vmss-fleet.sh --env deploy/azure-mainnet.env
#   ./scripts/azure/ssh-vmss-fleet.sh --cmd "hostname && nvidia-smi -L"
#   ./scripts/azure/ssh-vmss-fleet.sh --bootstrap
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"
SSH_KEY="${AZURE_VMSS_SSH_KEY_PATH:-${REPO_ROOT}/vmss_key.pem}"
SSH_USER="${AZURE_VMSS_SSH_USER:-azureuser}"
PUBLIC_IP="${AZURE_PUBLIC_IP:-4.249.252.26}"
NAT_START="${AZURE_VMSS_NAT_PORT_START:-50000}"
VMSS_NAME="${AZURE_VMSS_NAME:-vmss_3cf043e}"
RG="${AZURE_RESOURCE_GROUP:-YieldSwarm}"
REMOTE_CMD=""
BOOTSTRAP=0
DRY_RUN=0

log()  { printf '[ssh-fleet] %s\n' "$*"; }
warn() { printf '[ssh-fleet][warn] %s\n' "$*" >&2; }
die()  { printf '[ssh-fleet][fail] %s\n' "$*" >&2; exit 1; }

load_env() {
  [[ -f "${ENV_FILE}" ]] && set -a && source "${ENV_FILE}" && set +a
  SSH_KEY="${AZURE_VMSS_SSH_KEY_PATH:-${SSH_KEY}}"
  SSH_USER="${AZURE_VMSS_SSH_USER:-${SSH_USER}}"
  PUBLIC_IP="${AZURE_PUBLIC_IP:-${PUBLIC_IP}}"
  NAT_START="${AZURE_VMSS_NAT_PORT_START:-${NAT_START}}"
}

discover_instance_count() {
  if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
    az vmss list-instances \
      --resource-group "${RG}" \
      --name "${VMSS_NAME}" \
      --query "length(@)" -o tsv 2>/dev/null || echo "${AZURE_VMSS_CAPACITY:-2}"
  else
    echo "${AZURE_VMSS_CAPACITY:-2}"
  fi
}

ssh_instance() {
  local idx="$1"
  local port=$((NAT_START + idx))
  local target="${SSH_USER}@${PUBLIC_IP}"
  local ssh_opts=(-i "${SSH_KEY}" -p "${port}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

  log "=== instance ${idx} (${target}:${port}) ==="

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] ssh -p ${port} ${target}"
    return 0
  fi

  if [[ "${BOOTSTRAP}" == "1" ]]; then
    INSTALL_GPU="${INSTALL_GPU:-0}" ssh "${ssh_opts[@]}" "${target}" \
      "INSTALL_GPU=${INSTALL_GPU:-0} bash -s" < "${SCRIPT_DIR}/remote-bootstrap.sh"
    return $?
  fi

  if [[ -n "${REMOTE_CMD}" ]]; then
    ssh "${ssh_opts[@]}" "${target}" "${REMOTE_CMD}"
  else
    ssh "${ssh_opts[@]}" "${target}"
  fi
}

usage() {
  cat <<EOF
Usage: $0 [options]
  --env FILE         Env file (default: deploy/azure-mainnet.env)
  --cmd "COMMAND"    Run command on every instance
  --bootstrap        Pipe remote-bootstrap.sh to each instance
  --dry-run          Print SSH targets only
  --gpu-vmss NAME    Use alternate VMSS for GPU fleet
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --cmd) REMOTE_CMD="$2"; shift 2 ;;
    --bootstrap) BOOTSTRAP=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --gpu-vmss) VMSS_NAME="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

load_env

if [[ "${DRY_RUN}" == "0" ]]; then
  [[ -f "${SSH_KEY}" ]] || die "SSH key missing: ${SSH_KEY} (chmod 400)"
  chmod 400 "${SSH_KEY}" 2>/dev/null || true
fi

count="$(discover_instance_count)"
log "fleet size: ${count} instances on ${VMSS_NAME} via ${PUBLIC_IP}:${NAT_START}+"

failed=0
for ((i = 0; i < count; i++)); do
  ssh_instance "${i}" || failed=$((failed + 1))
done

if [[ "${failed}" -gt 0 ]]; then
  die "${failed} instance(s) failed"
fi
log "ssh-vmss-fleet complete"
