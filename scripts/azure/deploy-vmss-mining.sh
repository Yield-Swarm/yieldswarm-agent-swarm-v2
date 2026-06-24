#!/usr/bin/env bash
# Deploy Azure VMSS spot cluster for CPU mining workers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RG="${AZURE_RESOURCE_GROUP:-PoseidonMiningGroup}"
LOC="${AZURE_LOCATION:-eastus}"
COUNT="${AZURE_VMSS_COUNT:-10}"
TEMPLATE="${ROOT}/deploy/azure/vmss-miner-template.json"

[[ -f "${ROOT}/.run/azure-ssh.env" ]] && source "${ROOT}/.run/azure-ssh.env"

: "${AZURE_SSH_PUBLIC_KEY:?Run npm run azure:wire-ssh first}"

az group create --name "$RG" --location "$LOC" -o none
az deployment group create \
  --resource-group "$RG" \
  --template-file "$TEMPLATE" \
  --parameters \
    instanceCount="$COUNT" \
    sshPublicKey="$AZURE_SSH_PUBLIC_KEY" \
    adminUsername="${AZURE_ADMIN_USERNAME:-azureuser}" \
    miningWallet="${WALLET_LTC:-LYourWallet}"

echo "[azure-vmss] Deployed $COUNT spot instances in $RG"
