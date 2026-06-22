#!/usr/bin/env bash
# =============================================================================
# deploy-vmss-fleet.sh — Scale Azure VMSS, wire LB/NSG, SSH bootstrap all nodes
#
# Deploys:
#   • CPU mainnet VMSS (vmss_3cf043e) — scale + bootstrap
#   • GPU cluster VMSS (optional) — NC-series inference workers
#   • Load balancer health probes + NSG rules
#   • Custom domains (optional)
#
# Usage:
#   cp deploy/azure-mainnet.env.example deploy/azure-mainnet.env
#   az login
#   ./scripts/azure/deploy-vmss-fleet.sh --env deploy/azure-mainnet.env
#   ./scripts/azure/deploy-vmss-fleet.sh --dry-run
#   ./scripts/azure/deploy-vmss-fleet.sh --gpu-only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"

DRY_RUN=0
GPU_ONLY=0
SKIP_DOMAINS=0
SKIP_WIRE=0
SKIP_BOOTSTRAP=0
DEPLOY_TERRAFORM_GPU=0

log()  { printf '[deploy-fleet] %s\n' "$*"; }
warn() { printf '[deploy-fleet][warn] %s\n' "$*" >&2; }
die()  { printf '[deploy-fleet][fail] %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${REPO_ROOT}/deploy/azure-mainnet.env.example" ]]; then
      warn "creating ${ENV_FILE} from example — set AZURE_SUBSCRIPTION_ID and SSH key"
      cp "${REPO_ROOT}/deploy/azure-mainnet.env.example" "${ENV_FILE}"
    else
      die "missing env file: ${ENV_FILE}"
    fi
  fi
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
}

require_tools() {
  command -v ssh >/dev/null 2>&1 || die "ssh not installed"
  if [[ "${DRY_RUN}" == "1" ]]; then
    command -v az >/dev/null 2>&1 || warn "az CLI not installed — dry-run only"
    return 0
  fi
  command -v az >/dev/null 2>&1 || die "install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
  az account show >/dev/null 2>&1 || die "run: az login"
  if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
    az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
  fi
}

ensure_ssh_key() {
  local key_path="${AZURE_VMSS_SSH_KEY_PATH:-${REPO_ROOT}/vmss_key.pem}"
  if [[ -f "${key_path}" ]]; then
    chmod 400 "${key_path}"
    log "using SSH key ${key_path}"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    warn "[dry-run] would generate SSH key at ${key_path}"
    return 0
  fi
  step "Generating SSH key pair ${key_path}"
  ssh-keygen -t rsa -b 4096 -f "${key_path}" -N "" -C "yieldswarm-vmss@$(date +%Y%m%d)"
  chmod 400 "${key_path}"
  log "created ${key_path} — upload public key to VMSS if instances reject auth"
}

scale_cpu_vmss() {
  step "Scaling CPU VMSS ${AZURE_VMSS_NAME} → ${AZURE_VMSS_CAPACITY} instances"
  run az vmss scale \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_VMSS_NAME}" \
    --new-capacity "${AZURE_VMSS_CAPACITY}" \
    --output none
  log "CPU VMSS scaled"
}

deploy_gpu_vmss_terraform() {
  step "Deploying GPU cluster via Terraform (infra/terraform)"
  local tf_dir="${REPO_ROOT}/infra/terraform"
  [[ -d "${tf_dir}" ]] || die "terraform dir missing: ${tf_dir}"

  export ARM_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
  local gpu_size="${AZURE_GPU_VM_SIZE:-Standard_NC4as_T4_v3}"
  local gpu_count="${AZURE_GPU_VMSS_CAPACITY:-2}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] terraform apply azure_workers=${gpu_count} azure_vm_size=${gpu_size}"
    return 0
  fi

  run bash -c "cd '${tf_dir}' && terraform init -backend=false -input=false"
  run bash -c "cd '${tf_dir}' && terraform apply -auto-approve -input=false \
    -var 'enabled_fallbacks=[\"azure\"]' \
    -var 'akash_current_workers=0' \
    -var 'desired_total_workers=${gpu_count}' \
    -var 'azure_resource_group_name=${AZURE_RESOURCE_GROUP}' \
    -var 'azure_location=${AZURE_LOCATION}' \
    -var 'azure_vm_size=${gpu_size}' \
    -var 'ssh_public_key=$(ssh-keygen -y -f ${AZURE_VMSS_SSH_KEY_PATH:-${REPO_ROOT}/vmss_key.pem})'"
}

scale_or_create_gpu_vmss() {
  local gpu_name="${AZURE_GPU_VMSS_NAME:-vmss_gpu_yieldswarm}"
  local gpu_size="${AZURE_GPU_VM_SIZE:-Standard_NC4as_T4_v3}"
  local gpu_cap="${AZURE_GPU_VMSS_CAPACITY:-2}"

  if [[ "${DEPLOY_TERRAFORM_GPU}" == "1" ]]; then
    deploy_gpu_vmss_terraform
    return
  fi

  step "GPU VMSS ${gpu_name} (${gpu_size} × ${gpu_cap})"

  if az vmss show --resource-group "${AZURE_RESOURCE_GROUP}" --name "${gpu_name}" >/dev/null 2>&1; then
    run az vmss scale \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${gpu_name}" \
      --new-capacity "${gpu_cap}" \
      --output none
    log "scaled existing GPU VMSS ${gpu_name}"
    return
  fi

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would create GPU VMSS ${gpu_name} in ${AZURE_RESOURCE_GROUP}"
    return
  fi

  warn "GPU VMSS ${gpu_name} not found — use Terraform for full GPU cluster provisioning:"
  warn "  DEPLOY_TERRAFORM_GPU=1 ./scripts/azure/deploy-vmss-fleet.sh"
  warn "  or: cd infra/terraform && terraform apply -var azure_vm_size=${gpu_size}"
}

wire_and_domains() {
  if [[ "${SKIP_WIRE}" == "0" ]]; then
    step "Wiring load balancer + NSG"
    run "${REPO_ROOT}/scripts/wire_infrastructure.sh" --env "${ENV_FILE}"
  fi
  if [[ "${SKIP_DOMAINS}" == "0" ]]; then
    step "Provisioning custom domains"
    run "${SCRIPT_DIR}/provision-custom-domains.sh" --env "${ENV_FILE}" || warn "domain provisioning skipped/failed"
  fi
}

bootstrap_fleet() {
  if [[ "${SKIP_BOOTSTRAP}" == "1" ]]; then
    warn "skipping SSH bootstrap"
    return 0
  fi
  step "SSH bootstrap — CPU VMSS fleet"
  run "${SCRIPT_DIR}/ssh-vmss-fleet.sh" --env "${ENV_FILE}" --bootstrap

  if [[ -n "${AZURE_GPU_VMSS_NAME:-}" ]] && az vmss show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_GPU_VMSS_NAME}" >/dev/null 2>&1; then
    step "SSH bootstrap — GPU VMSS fleet"
    INSTALL_GPU=1 run "${SCRIPT_DIR}/ssh-vmss-fleet.sh" \
      --env "${ENV_FILE}" --gpu-vmss "${AZURE_GPU_VMSS_NAME}" --bootstrap \
      || warn "GPU fleet bootstrap failed — check NAT rules for GPU VMSS"
  fi
}

print_summary() {
  step "Deployment summary"
  cat <<EOF
  Resource group:  ${AZURE_RESOURCE_GROUP}
  Public IP:         ${AZURE_PUBLIC_IP}
  CPU VMSS:          ${AZURE_VMSS_NAME} (capacity ${AZURE_VMSS_CAPACITY})
  GPU VMSS:          ${AZURE_GPU_VMSS_NAME:-<not configured>}
  SSH:               ssh -i ${AZURE_VMSS_SSH_KEY_PATH:-vmss_key.pem} -p ${AZURE_VMSS_NAT_PORT_START:-50000} ${AZURE_VMSS_SSH_USER:-azureuser}@${AZURE_PUBLIC_IP}

  Dashboard:         http://${AZURE_PUBLIC_IP}:${MAINNET_APP_PORT:-8080}/command-center
  Health:            http://${AZURE_PUBLIC_IP}:${MAINNET_APP_PORT:-8080}/api/health

  Verify fleet:
    ./scripts/azure/ssh-vmss-fleet.sh --env ${ENV_FILE} --cmd "systemctl is-active yieldswarm-backend"
EOF
}

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --gpu-only) GPU_ONLY=1; shift ;;
    --terraform-gpu) DEPLOY_TERRAFORM_GPU=1; shift ;;
    --skip-domains) SKIP_DOMAINS=1; shift ;;
    --skip-wire) SKIP_WIRE=1; shift ;;
    --skip-bootstrap) SKIP_BOOTSTRAP=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

main() {
  load_env
  require_tools
  ensure_ssh_key

  if [[ "${GPU_ONLY}" == "0" ]]; then
    scale_cpu_vmss
  fi
  scale_or_create_gpu_vmss
  wire_and_domains
  bootstrap_fleet
  print_summary
  log "deploy-vmss-fleet complete"
}

main "$@"
