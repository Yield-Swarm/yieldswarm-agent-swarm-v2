#!/usr/bin/env bash
# =============================================================================
# gpu-metrics-agent.sh — Install Azure Monitor Agent + DCGM exporter on GPU nodes
#
# Pushes in-guest GPU metrics (utilization, memory, power) for autoscale rules
# beyond host-level Percentage CPU. Run via SSH fleet bootstrap or standalone.
#
# Usage (on GPU instance):
#   sudo ./scripts/azure/gpu-metrics-agent.sh
#
# Usage (fleet-wide via SSH helper):
#   ./scripts/azure/ssh-vmss-fleet.sh --gpu-vmss vmss_gpu_yieldswarm \\
#     --cmd "curl -fsSL ... | sudo bash -s"
#   ./scripts/azure/gpu-metrics-agent.sh --env deploy/azure-mainnet.env --fleet
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"
FLEET_MODE=0
DRY_RUN=0

DCGM_EXPORTER_VERSION="${DCGM_EXPORTER_VERSION:-3.3.5-3.4.0-ubuntu22.04}"
DCGM_EXPORTER_PORT="${DCGM_EXPORTER_PORT:-9400}"
CUSTOM_METRIC_NAMESPACE="${AZURE_CUSTOM_METRIC_NAMESPACE:-YieldSwarm/GPU}"

log()  { printf '[gpu-metrics] %s\n' "$*"; }
warn() { printf '[gpu-metrics][warn] %s\n' "$*" >&2; }
die()  { printf '[gpu-metrics][fail] %s\n' "$*" >&2; exit 1; }

run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

install_on_node() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die "run as root on the target node (sudo)"
  fi

  step() { log "==> $*"; }

  step "Installing Azure Monitor Agent (ama)"
  if command -v apt-get >/dev/null 2>&1; then
  run bash -c 'curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg'
  run bash -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/microsoft-prod.list' || true
  run apt-get update -qq
  run apt-get install -y -qq azuremonitoragent || warn "azuremonitoragent package install failed — use portal Data Collection Rule"
  else
    warn "non-apt distro — install Azure Monitor Agent manually"
  fi

  step "Installing NVIDIA DCGM exporter (Docker)"
  if command -v docker >/dev/null 2>&1; then
    run docker pull "nvcr.io/nvidia/k8s/dcgm-exporter:${DCGM_EXPORTER_VERSION}" || true
    if docker ps -a --format '{{.Names}}' | grep -q '^dcgm-exporter$'; then
      run docker rm -f dcgm-exporter
    fi
    run docker run -d --restart unless-stopped --gpus all \
      --name dcgm-exporter \
      -p "${DCGM_EXPORTER_PORT}:9400" \
      "nvcr.io/nvidia/k8s/dcgm-exporter:${DCGM_EXPORTER_VERSION}"
  else
    warn "docker not found — install NVIDIA DCGM exporter manually"
  fi

  step "Prometheus scrape config snippet"
  cat <<EOF

# Add to Azure Monitor Data Collection Rule (Prometheus receiver):
#   DCGM_FI_DEV_GPU_UTIL, DCGM_FI_DEV_FB_USED, DCGM_FI_DEV_POWER_USAGE
# Custom metric namespace: ${CUSTOM_METRIC_NAMESPACE}
# Endpoint: http://localhost:${DCGM_EXPORTER_PORT}/metrics

# Example autoscale condition (portal/ARM — custom metrics):
#   ${CUSTOM_METRIC_NAMESPACE} GPU Utilization > 80 avg 5m → scale out

EOF
  log "gpu-metrics-agent install complete on $(hostname)"
}

deploy_fleet() {
  local ssh_script="${SCRIPT_DIR}/ssh-vmss-fleet.sh"
  [[ -x "${ssh_script}" ]] || die "missing ${ssh_script}"

  log "Deploying GPU metrics agent across fleet"
  run "${ssh_script}" \
    --env "${ENV_FILE}" \
    --gpu-vmss "${AZURE_GPU_VMSS_NAME:-vmss_gpu_yieldswarm}" \
    --cmd "curl -fsSL file://${SCRIPT_DIR}/gpu-metrics-agent.sh | sudo bash -s" \
    || warn "fleet deploy failed — run manually on each GPU node"
}

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --fleet) FLEET_MODE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

if [[ "${FLEET_MODE}" == "1" ]]; then
  load_env
  deploy_fleet
else
  install_on_node
fi
