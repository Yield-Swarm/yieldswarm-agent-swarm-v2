#!/usr/bin/env bash
# Deploy YieldSwarm core integration backend to Azure Container Instances.
#
# Prerequisites:
#   az login
#   export AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP (or use defaults)
#   Vault AppRole: VAULT_ROLE_ID + VAULT_WRAPPED_SECRET_ID (from akash-vault-prepare)
#
# Usage:
#   ./scripts/deploy-azure-core.sh
#   ./scripts/deploy-azure-core.sh --dry-run
#   MINING_DRY_RUN=1 ./scripts/deploy-azure-core.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
  esac
done

log() { printf '[azure-aci] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

command -v az >/dev/null 2>&1 || die "Azure CLI (az) not installed"

# Load deploy config if present
# shellcheck disable=SC1091
[[ -f deploy/config.env ]] && source deploy/config.env
# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

RG="${AZURE_RESOURCE_GROUP:-yieldswarm-rg}"
LOCATION="${AZURE_LOCATION:-eastus}"
SUB="${AZURE_SUBSCRIPTION_ID:-}"
IMAGE="${BACKEND_IMAGE:-ghcr.io/${GHCR_OWNER:-yieldswarm}/yieldswarm-backend:${IMAGE_TAG:-latest}}"
DNS_LABEL="${AZURE_DNS_LABEL:-yieldswarm-core}"
PARAMS_FILE="${AZURE_PARAMS_FILE:-${REPO_ROOT}/.run/azure-deploy.parameters.json}"

export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"

# Optional: mint wrapped SecretID via existing Vault prep script
if [[ -z "${VAULT_WRAPPED_SECRET_ID:-}" && -x "${REPO_ROOT}/scripts/akash-vault-prepare.sh" ]]; then
  log "preparing Vault AppRole wrap token..."
  # shellcheck disable=SC1090
  eval "$("${REPO_ROOT}/scripts/akash-vault-prepare.sh" export 2>/dev/null || true)"
fi

mkdir -p "${REPO_ROOT}/.run"

# Build parameters JSON from environment (never echo secrets)
export PARAMS_FILE
python3 - <<'PY' > "${PARAMS_FILE}"
import json, os
from pathlib import Path

params = {
    "containerGroupName": os.getenv("AZURE_CONTAINER_GROUP", "yieldswarm-core"),
    "location": os.getenv("AZURE_LOCATION", "eastus"),
    "dnsNameLabel": os.getenv("AZURE_DNS_LABEL", "yieldswarm-core"),
    "containerImage": os.getenv("BACKEND_IMAGE") or f"ghcr.io/{os.getenv('GHCR_OWNER', 'yieldswarm')}/yieldswarm-backend:{os.getenv('IMAGE_TAG', 'latest')}",
    "cpuCores": int(os.getenv("AZURE_CPU", "4")),
    "memoryInGb": int(os.getenv("AZURE_MEMORY_GB", "16")),
    "vaultAddr": os.getenv("VAULT_ADDR", "https://vault.yieldswarm.io:8200"),
    "vaultRoleId": os.getenv("VAULT_ROLE_ID", ""),
    "vaultWrappedSecretId": os.getenv("VAULT_WRAPPED_SECRET_ID", ""),
    "akashOwnerAddress": os.getenv("AKASH_OWNER_ADDRESS", os.getenv("AKASH_ACCOUNT_ADDRESS", "")),
    "agentSwarmMasterKey": os.getenv("AGENTSWARM_MASTER_KEY", ""),
    "databaseUrl": os.getenv("DATABASE_URL", ""),
    "ghcrUser": os.getenv("GHCR_USER", os.getenv("GITHUB_ACTOR", "")),
    "ghcrToken": os.getenv("GHCR_TOKEN", os.getenv("GITHUB_TOKEN", "")),
}
out = {"parameters": {k: {"value": v} for k, v in params.items()}}
Path(os.environ["PARAMS_FILE"]).write_text(json.dumps(out, indent=2))
print(json.dumps({k: ("[set]" if v else "") for k, v in params.items()}, indent=2))
PY

log "parameters written to ${PARAMS_FILE} (secrets redacted above)"

if [[ -n "$SUB" ]]; then
  log "setting subscription ${SUB}"
  az account set --subscription "$SUB"
fi

log "ensuring resource group ${RG} in ${LOCATION}"
if [[ "$DRY_RUN" -eq 0 ]]; then
  az group create --name "$RG" --location "$LOCATION" --output none 2>/dev/null || true
else
  log "[dry-run] would create resource group ${RG}"
fi

DEPLOY_NAME="yieldswarm-core-$(date -u +%Y%m%d%H%M%S)"
log "deploying ACI template (deployment=${DEPLOY_NAME})"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] az deployment group create --resource-group ${RG} --template-file deploy/azure-deploy.yml --parameters @${PARAMS_FILE}"
  exit 0
fi

RESULT=$(az deployment group create \
  --name "$DEPLOY_NAME" \
  --resource-group "$RG" \
  --template-file "${REPO_ROOT}/deploy/azure-deploy.yml" \
  --parameters "@${PARAMS_FILE}" \
  --query 'properties.outputs' \
  --output json)

FQDN=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('fqdn',{}).get('value',''))")
CC_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('commandCenterUrl',{}).get('value',''))")

log "deployment complete"
log "  FQDN:            ${FQDN}"
log "  Command Center:  ${CC_URL}"
log "  Health:          http://${FQDN}:8080/api/health"
log "  Single Pane:     http://${FQDN}:8080/api/single-pane/overview"
