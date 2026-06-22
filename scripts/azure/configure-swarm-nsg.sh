#!/usr/bin/env bash
# Azure NSG — open YieldSwarm swarm P2P + dashboard ports on VMSS.
#
# Usage:
#   export AZURE_RESOURCE_GROUP=YieldSwarm
#   export AZURE_NSG_NAME=basicNsgvnet-centralus-nic01
#   ./scripts/azure/configure-swarm-nsg.sh
#
# Optional:
#   AZURE_LB_IP=4.249.252.26
#   SWARM_PORT_START=50000
#   SWARM_PORT_END=50003
set -euo pipefail

RG="${AZURE_RESOURCE_GROUP:-YieldSwarm}"
NSG="${AZURE_NSG_NAME:-basicNsgvnet-centralus-nic01}"
PORT_START="${SWARM_PORT_START:-50000}"
PORT_END="${SWARM_PORT_END:-50003}"

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: Azure CLI (az) not installed. See https://learn.microsoft.com/cli/azure/install-azure-cli" >&2
  exit 1
fi

echo "[azure-nsg] resource group: ${RG}"
echo "[azure-nsg] nsg: ${NSG}"
echo "[azure-nsg] opening TCP ${PORT_START}-${PORT_END} (Swarm P2P)"

az network nsg rule create \
  --resource-group "${RG}" \
  --nsg-name "${NSG}" \
  --name AllowSwarmP2P \
  --priority 1010 \
  --destination-port-ranges "${PORT_START}-${PORT_END}" \
  --protocol Tcp \
  --access Allow \
  --direction Inbound \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*'

echo "[azure-nsg] ensuring dashboard port 8080..."
az network nsg rule create \
  --resource-group "${RG}" \
  --nsg-name "${NSG}" \
  --name AllowYieldSwarm8080 \
  --priority 1011 \
  --destination-port-ranges 8080 \
  --protocol Tcp \
  --access Allow \
  --direction Inbound \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  2>/dev/null || echo "[azure-nsg] rule AllowYieldSwarm8080 may already exist"

echo "[azure-nsg] done. Load balancer: ${AZURE_LB_IP:-set AZURE_LB_IP to verify}"
