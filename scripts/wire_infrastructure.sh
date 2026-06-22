#!/usr/bin/env bash
# =============================================================================
# wire_infrastructure.sh — Azure Mainnet VMSS + Load Balancer wiring
#
# 1. Validates resource group, load balancer, VMSS, NSG, public IP
# 2. Opens NSG rules for 80/443 and SSH/NAT/P2P 50000-50003
# 3. Configures LB health probe + forwarding rules to mainnet app port
#
# Usage:
#   ./scripts/wire_infrastructure.sh
#   ./scripts/wire_infrastructure.sh --env deploy/azure-mainnet.env
#   ./scripts/wire_infrastructure.sh --dry-run
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"
DRY_RUN=0

# Defaults (overridden by env file)
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-YieldSwarm}"
AZURE_LOCATION="${AZURE_LOCATION:-centralus}"
AZURE_PUBLIC_IP="${AZURE_PUBLIC_IP:-4.249.252.26}"
AZURE_PUBLIC_IP_NAME="${AZURE_PUBLIC_IP_NAME:-Loadbalanceraitrained-publicip}"
AZURE_LOAD_BALANCER_NAME="${AZURE_LOAD_BALANCER_NAME:-Loadbalanceraitrained}"
AZURE_VMSS_NAME="${AZURE_VMSS_NAME:-vmss_3cf043e}"
AZURE_NSG_NAME="${AZURE_NSG_NAME:-basicNsgvnet-centralus-nic01}"
MAINNET_APP_PORT="${MAINNET_APP_PORT:-8080}"
MAINNET_TLS_PORT="${MAINNET_TLS_PORT:-8443}"
MAINNET_HEALTH_PATH="${MAINNET_HEALTH_PATH:-/api/health}"
MAINNET_P2P_PORT_START="${MAINNET_P2P_PORT_START:-50000}"
MAINNET_P2P_PORT_END="${MAINNET_P2P_PORT_END:-50003}"
LB_FRONTEND_HTTP_PORT="${LB_FRONTEND_HTTP_PORT:-80}"
LB_FRONTEND_HTTPS_PORT="${LB_FRONTEND_HTTPS_PORT:-443}"
LB_PROBE_NAME="${LB_PROBE_NAME:-yieldswarm-mainnet-health}"
LB_RULE_HTTP_NAME="${LB_RULE_HTTP_NAME:-yieldswarm-mainnet-http}"
LB_RULE_HTTPS_NAME="${LB_RULE_HTTPS_NAME:-yieldswarm-mainnet-https}"
LB_BACKEND_POOL_NAME="${LB_BACKEND_POOL_NAME:-backend-pool}"

log()  { printf '[wire] %s\n' "$*"; }
warn() { printf '[wire][warn] %s\n' "$*" >&2; }
die()  { printf '[wire][fail] %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

run_az() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] az $*"
    return 0
  fi
  az "$@"
}

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    log "loading ${ENV_FILE}"
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
  else
    warn "env file not found (${ENV_FILE}) — using defaults"
  fi
}

require_az() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    command -v az >/dev/null 2>&1 || warn "Azure CLI not installed — dry-run continues with planned commands only"
    return 0
  fi
  command -v az >/dev/null 2>&1 || die "Azure CLI (az) not installed"
  az account show >/dev/null 2>&1 || die "not logged in — run: az login"
  if [[ -n "${AZURE_SUBSCRIPTION_ID}" ]]; then
    az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
  fi
}

validate_resources() {
  step "Validating Azure resources in ${AZURE_RESOURCE_GROUP}"

  run_az group show --name "${AZURE_RESOURCE_GROUP}" --output none \
    || die "resource group missing: ${AZURE_RESOURCE_GROUP}"

  run_az network public-ip show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_PUBLIC_IP_NAME}" --output none \
    || die "public IP missing: ${AZURE_PUBLIC_IP_NAME}"

  if [[ "${DRY_RUN}" == "0" ]]; then
    local pip
    pip="$(az network public-ip show \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AZURE_PUBLIC_IP_NAME}" \
      --query ipAddress -o tsv)"
    if [[ "${pip}" != "${AZURE_PUBLIC_IP}" ]]; then
      warn "public IP mismatch: expected ${AZURE_PUBLIC_IP}, found ${pip}"
    else
      log "public IP confirmed: ${pip}"
    fi
  fi

  run_az network lb show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_LOAD_BALANCER_NAME}" --output none \
    || die "load balancer missing: ${AZURE_LOAD_BALANCER_NAME}"

  run_az vmss show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_VMSS_NAME}" --output none \
    || die "VMSS missing: ${AZURE_VMSS_NAME}"

  run_az network nsg show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_NSG_NAME}" --output none \
    || die "NSG missing: ${AZURE_NSG_NAME}"

  log "all core resources present"
}

ensure_nsg_rule() {
  local name="$1" priority="$2" ports="$3" description="$4"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would create NSG rule ${name} ports ${ports}"
    return 0
  fi
  if az network nsg rule show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --nsg-name "${AZURE_NSG_NAME}" \
    --name "${name}" >/dev/null 2>&1; then
    log "NSG rule exists: ${name}"
    return 0
  fi
  run_az network nsg rule create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --nsg-name "${AZURE_NSG_NAME}" \
    --name "${name}" \
    --priority "${priority}" \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes Internet \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges "${ports}" \
    --description "${description}" \
    --output none
  log "created NSG rule: ${name} (${ports})"
}

configure_nsg() {
  step "Configuring NSG ${AZURE_NSG_NAME}"
  ensure_nsg_rule "Allow-YieldSwarm-HTTP" 1001 "${LB_FRONTEND_HTTP_PORT}" "Mainnet web HTTP"
  ensure_nsg_rule "Allow-YieldSwarm-HTTPS" 1002 "${LB_FRONTEND_HTTPS_PORT}" "Mainnet web HTTPS"
  ensure_nsg_rule "Allow-YieldSwarm-App" 1003 "${MAINNET_APP_PORT}" "YieldSwarm backend direct"
  ensure_nsg_rule "Allow-YieldSwarm-NAT-P2P" 1010 "${MAINNET_P2P_PORT_START}-${MAINNET_P2P_PORT_END}" "SSH inbound NAT + validator P2P"
}

ensure_lb_backend_pool() {
  step "Ensuring load balancer backend pool ${LB_BACKEND_POOL_NAME}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would ensure backend pool ${LB_BACKEND_POOL_NAME}"
    return 0
  fi
  if ! az network lb address-pool show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --name "${LB_BACKEND_POOL_NAME}" >/dev/null 2>&1; then
    run_az network lb address-pool create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
      --name "${LB_BACKEND_POOL_NAME}" \
      --output none
    log "created backend pool ${LB_BACKEND_POOL_NAME}"
  else
    log "backend pool exists: ${LB_BACKEND_POOL_NAME}"
  fi

  # Attach VMSS to backend pool if not already attached
  local pool_id
  pool_id="$(az network lb address-pool show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --name "${LB_BACKEND_POOL_NAME}" \
    --query id -o tsv)"
  run_az vmss update \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_VMSS_NAME}" \
    --add virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].ipConfigurations[0].loadBalancerBackendAddressPools \
    id="${pool_id}" \
    --output none 2>/dev/null || warn "VMSS may already be attached to backend pool"
}

configure_lb_probe_and_rules() {
  step "Configuring LB health probe and forwarding rules"

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] probe HTTP ${MAINNET_APP_PORT}${MAINNET_HEALTH_PATH}"
    log "[dry-run] rule ${LB_FRONTEND_HTTP_PORT} -> ${MAINNET_APP_PORT}"
    log "[dry-run] rule ${LB_FRONTEND_HTTPS_PORT} -> ${MAINNET_TLS_PORT}"
    return 0
  fi

  if ! az network lb probe show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --name "${LB_PROBE_NAME}" >/dev/null 2>&1; then
    run_az network lb probe create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
      --name "${LB_PROBE_NAME}" \
      --protocol Http \
      --port "${MAINNET_APP_PORT}" \
      --path "${MAINNET_HEALTH_PATH}" \
      --interval 15 \
      --threshold 2 \
      --output none
    log "created health probe ${LB_PROBE_NAME}"
  else
    run_az network lb probe update \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
      --name "${LB_PROBE_NAME}" \
      --protocol Http \
      --port "${MAINNET_APP_PORT}" \
      --path "${MAINNET_HEALTH_PATH}" \
      --output none
    log "updated health probe ${LB_PROBE_NAME}"
  fi

  local frontend_ip_name
  frontend_ip_name="$(az network lb frontend-ip list \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --query "[0].name" -o tsv)"
  [[ -n "${frontend_ip_name}" ]] || die "no LB frontend IP configuration found"

  if ! az network lb rule show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --name "${LB_RULE_HTTP_NAME}" >/dev/null 2>&1; then
    run_az network lb rule create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
      --name "${LB_RULE_HTTP_NAME}" \
      --protocol Tcp \
      --frontend-ip-name "${frontend_ip_name}" \
      --frontend-port "${LB_FRONTEND_HTTP_PORT}" \
      --backend-port "${MAINNET_APP_PORT}" \
      --backend-pool-name "${LB_BACKEND_POOL_NAME}" \
      --probe-name "${LB_PROBE_NAME}" \
      --output none
    log "created LB HTTP rule ${LB_RULE_HTTP_NAME}"
  fi

  if ! az network lb rule show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
    --name "${LB_RULE_HTTPS_NAME}" >/dev/null 2>&1; then
    run_az network lb rule create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --lb-name "${AZURE_LOAD_BALANCER_NAME}" \
      --name "${LB_RULE_HTTPS_NAME}" \
      --protocol Tcp \
      --frontend-ip-name "${frontend_ip_name}" \
      --frontend-port "${LB_FRONTEND_HTTPS_PORT}" \
      --backend-port "${MAINNET_TLS_PORT}" \
      --backend-pool-name "${LB_BACKEND_POOL_NAME}" \
      --probe-name "${LB_PROBE_NAME}" \
      --output none
    log "created LB HTTPS rule ${LB_RULE_HTTPS_NAME}"
  fi
}

print_summary() {
  step "Wiring summary"
  cat <<EOF
  Resource group:  ${AZURE_RESOURCE_GROUP}
  Public IP:       ${AZURE_PUBLIC_IP} (${AZURE_PUBLIC_IP_NAME})
  Load balancer:   ${AZURE_LOAD_BALANCER_NAME}
  VMSS:            ${AZURE_VMSS_NAME}
  NSG:             ${AZURE_NSG_NAME}
  Health probe:    HTTP ${MAINNET_APP_PORT}${MAINNET_HEALTH_PATH}
  SSH instance 0:  ssh -i ${AZURE_VMSS_SSH_KEY_PATH:-vmss_key.pem} -p ${MAINNET_P2P_PORT_START} ${AZURE_VMSS_SSH_USER:-azureuser}@${AZURE_PUBLIC_IP}
  Next:            ./scripts/azure/provision-custom-domains.sh --env ${ENV_FILE}
EOF
}

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

main() {
  load_env
  require_az
  validate_resources
  configure_nsg
  ensure_lb_backend_pool
  configure_lb_probe_and_rules
  print_summary
  log "wire_infrastructure complete"
}

main "$@"
