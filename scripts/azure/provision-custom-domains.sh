#!/usr/bin/env bash
# =============================================================================
# provision-custom-domains.sh — Azure Front Door + managed TLS for mainnet
#
# Maps custom domains (mainnet.yieldswarm.network, api.yieldswarm.network)
# to the YieldSwarm load balancer origin (4.249.252.26) with Azure managed
# certificates and documents required DNS records.
#
# Usage:
#   ./scripts/azure/provision-custom-domains.sh
#   ./scripts/azure/provision-custom-domains.sh --env deploy/azure-mainnet.env
#   ./scripts/azure/provision-custom-domains.sh --dry-run
#   ./scripts/azure/provision-custom-domains.sh --print-dns-only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"
DRY_RUN=0
PRINT_DNS_ONLY=0

AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-YieldSwarm}"
AZURE_LOCATION="${AZURE_LOCATION:-global}"
AZURE_PUBLIC_IP="${AZURE_PUBLIC_IP:-4.249.252.26}"
MAINNET_APP_PORT="${MAINNET_APP_PORT:-8080}"
MAINNET_DOMAIN="${MAINNET_DOMAIN:-mainnet.yieldswarm.network}"
API_DOMAIN="${API_DOMAIN:-api.yieldswarm.network}"
DNS_ZONE="${DNS_ZONE:-yieldswarm.network}"
AFD_PROFILE_NAME="${AFD_PROFILE_NAME:-afd-yieldswarm-mainnet}"
AFD_ENDPOINT_NAME="${AFD_ENDPOINT_NAME:-yieldswarm-mainnet-edge}"
AFD_ORIGIN_GROUP_NAME="${AFD_ORIGIN_GROUP_NAME:-yieldswarm-vmss-origins}"
AFD_ORIGIN_NAME="${AFD_ORIGIN_NAME:-yieldswarm-lb-origin}"
AFD_ROUTE_NAME="${AFD_ROUTE_NAME:-yieldswarm-mainnet-route}"
AFD_SKU="${AFD_SKU:-Standard_AzureFrontDoor}"

log()  { printf '[domains] %s\n' "$*"; }
warn() { printf '[domains][warn] %s\n' "$*" >&2; }
die()  { printf '[domains][fail] %s\n' "$*" >&2; exit 1; }
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
  fi
}

require_az() {
  if [[ "${DRY_RUN}" == "1" || "${PRINT_DNS_ONLY}" == "1" ]]; then
    command -v az >/dev/null 2>&1 || warn "Azure CLI not installed — dry-run continues"
    return 0
  fi
  command -v az >/dev/null 2>&1 || die "Azure CLI not installed"
  az account show >/dev/null 2>&1 || die "run: az login"
  if [[ -n "${AZURE_SUBSCRIPTION_ID}" ]]; then
    az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
  fi
}

print_dns_plan() {
  step "DNS records required"
  local fd_host="<front-door-endpoint>.z01.azurefd.net"
  if [[ "${DRY_RUN}" == "0" && "${PRINT_DNS_ONLY}" == "0" ]]; then
    fd_host="$(az afd endpoint show \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --endpoint-name "${AFD_ENDPOINT_NAME}" \
      --query hostName -o tsv 2>/dev/null || echo "<front-door-endpoint>.z01.azurefd.net")"
  fi
  cat <<EOF

  === RECOMMENDED (Front Door + managed TLS) ===
  Type   Host                              Value
  ----   ------------------------------    ----------------------------------
  CNAME  ${MAINNET_DOMAIN}                   ${fd_host}
  CNAME  ${API_DOMAIN}                       ${fd_host}
  TXT    _dnsauth.${MAINNET_DOMAIN}          (from: az afd custom-domain show)
  TXT    _dnsauth.${API_DOMAIN}              (from: az afd custom-domain show)

  === DIRECT L4 FALLBACK (load balancer only) ===
  Type   Host                              Value
  ----   ------------------------------    ----------------------------------
  A      ${MAINNET_DOMAIN}                   ${AZURE_PUBLIC_IP}
  A      ${API_DOMAIN}                       ${AZURE_PUBLIC_IP}

  After DNS propagates, validate managed certificates:
    az afd custom-domain list \\
      --resource-group ${AZURE_RESOURCE_GROUP} \\
      --profile-name ${AFD_PROFILE_NAME} -o table
EOF
}

ensure_front_door_profile() {
  step "Ensuring Azure Front Door profile ${AFD_PROFILE_NAME}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would create AFD profile ${AFD_PROFILE_NAME} sku=${AFD_SKU}"
    return 0
  fi
  if ! az afd profile show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" >/dev/null 2>&1; then
    run_az afd profile create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --sku "${AFD_SKU}" \
      --output none
    log "created Front Door profile"
  else
    log "Front Door profile exists"
  fi
}

ensure_endpoint() {
  step "Ensuring Front Door endpoint ${AFD_ENDPOINT_NAME}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi
  if ! az afd endpoint show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --endpoint-name "${AFD_ENDPOINT_NAME}" >/dev/null 2>&1; then
    run_az afd endpoint create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --endpoint-name "${AFD_ENDPOINT_NAME}" \
      --enabled-state Enabled \
      --output none
  fi
}

ensure_origin_and_route() {
  step "Configuring origin ${AZURE_PUBLIC_IP}:${MAINNET_APP_PORT}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] origin host=${AZURE_PUBLIC_IP} port=${MAINNET_APP_PORT}"
    return 0
  fi

  if ! az afd origin-group show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --origin-group-name "${AFD_ORIGIN_GROUP_NAME}" >/dev/null 2>&1; then
    run_az afd origin-group create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --origin-group-name "${AFD_ORIGIN_GROUP_NAME}" \
      --probe-request-type GET \
      --probe-protocol Http \
      --probe-path "/api/health" \
      --probe-interval-in-seconds 30 \
      --sample-size 4 \
      --successful-samples-required 3 \
      --additional-latency-in-milliseconds 50 \
      --output none
  fi

  if ! az afd origin show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --origin-group-name "${AFD_ORIGIN_GROUP_NAME}" \
    --origin-name "${AFD_ORIGIN_NAME}" >/dev/null 2>&1; then
    run_az afd origin create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --origin-group-name "${AFD_ORIGIN_GROUP_NAME}" \
      --origin-name "${AFD_ORIGIN_NAME}" \
      --host-name "${AZURE_PUBLIC_IP}" \
      --http-port 80 \
      --https-port 443 \
      --origin-host-header "${AZURE_PUBLIC_IP}" \
      --priority 1 \
      --weight 1000 \
      --enabled-state Enabled \
      --output none
  fi

  if ! az afd route show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --endpoint-name "${AFD_ENDPOINT_NAME}" \
    --route-name "${AFD_ROUTE_NAME}" >/dev/null 2>&1; then
    run_az afd route create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --endpoint-name "${AFD_ENDPOINT_NAME}" \
      --route-name "${AFD_ROUTE_NAME}" \
      --origin-group "${AFD_ORIGIN_GROUP_NAME}" \
      --supported-protocols Http Https \
      --https-redirect Enabled \
      --forwarding-protocol HttpOnly \
      --link-to-default-domain Enabled \
      --patterns-to-match '/*' \
      --output none
  fi
}

bind_custom_domain() {
  local domain="$1"
  local rule_set="${2:-default}"
  step "Binding custom domain ${domain}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would bind ${domain} with Azure managed certificate"
    return 0
  fi

  local safe_name
  safe_name="$(echo "${domain}" | tr '.' '-')"

  if ! az afd custom-domain show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --custom-domain-name "${safe_name}" >/dev/null 2>&1; then
    run_az afd custom-domain create \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --profile-name "${AFD_PROFILE_NAME}" \
      --custom-domain-name "${safe_name}" \
      --host-name "${domain}" \
      --minimum-tls-version TLS12 \
      --certificate-type ManagedCertificate \
      --output none
    log "created custom domain ${domain} — add DNS validation TXT record"
  fi

  az afd custom-domain show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --custom-domain-name "${safe_name}" \
    --query "{host:hostName,validation:validationProperties.validationToken,domainValidation:domainValidationState}" \
    -o jsonc || true

  run_az afd route update \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --endpoint-name "${AFD_ENDPOINT_NAME}" \
    --route-name "${AFD_ROUTE_NAME}" \
    --custom-domains "${safe_name}" \
    --rule-set-name "${rule_set}" \
    --output none 2>/dev/null || warn "attach ${domain} to route manually if update failed"
}

provision_dns_zone_records_optional() {
  # If Azure DNS hosts yieldswarm.network in the same subscription, create records automatically.
  step "Optional: Azure DNS zone records for ${DNS_ZONE}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would create CNAME records in zone ${DNS_ZONE} if zone exists"
    return 0
  fi
  if ! az network dns zone show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${DNS_ZONE}" >/dev/null 2>&1; then
    warn "Azure DNS zone ${DNS_ZONE} not in ${AZURE_RESOURCE_GROUP} — create CNAME records at your registrar"
    return 0
  fi
  local fd_host
  fd_host="$(az afd endpoint show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --profile-name "${AFD_PROFILE_NAME}" \
    --endpoint-name "${AFD_ENDPOINT_NAME}" \
    --query hostName -o tsv)"

  for host in "${MAINNET_DOMAIN}" "${API_DOMAIN}"; do
    local record_name="${host%%.${DNS_ZONE}}"
    run_az network dns record-set cname set-record \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --zone-name "${DNS_ZONE}" \
      --record-set-name "${record_name}" \
      --cname "${fd_host}" \
      --output none 2>/dev/null \
      || warn "could not set CNAME for ${host}"
  done
}

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --print-dns-only) PRINT_DNS_ONLY=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

main() {
  load_env
  require_az

  if [[ "${PRINT_DNS_ONLY}" == "1" ]]; then
    print_dns_plan
    exit 0
  fi

  ensure_front_door_profile
  ensure_endpoint
  ensure_origin_and_route
  bind_custom_domain "${MAINNET_DOMAIN}"
  bind_custom_domain "${API_DOMAIN}"
  provision_dns_zone_records_optional
  print_dns_plan
  log "provision-custom-domains complete"
}

main "$@"
