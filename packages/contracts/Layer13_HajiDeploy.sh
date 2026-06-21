#!/usr/bin/env bash
# Layer 13: Haji Cloud deployment runtime
# Requires: HAJI_DEPLOY_SECRET_TOKEN, HAJI_API_ENDPOINT (optional)
set -euo pipefail

HAJI_API_ENDPOINT="${HAJI_API_ENDPOINT:-https://api.haji.cloud/v2/deploy}"
: "${HAJI_DEPLOY_SECRET_TOKEN:?HAJI_DEPLOY_SECRET_TOKEN required}"

CLUSTER_NAME="${HAJI_CLUSTER_NAME:-swarm-os-orchestrator-cluster}"
IMAGE="${HAJI_IMAGE:-ghcr.io/yield-swarm/core-engine:latest}"
SHARDS="${HAJI_SHARDS:-64}"

echo "==> Instantiating Haji Cloud deployment: ${CLUSTER_NAME}"

curl -sfS -X POST "${HAJI_API_ENDPOINT}" \
  -H "Authorization: Bearer ${HAJI_DEPLOY_SECRET_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"cluster_name\": \"${CLUSTER_NAME}\",
    \"image\": \"${IMAGE}\",
    \"shards\": ${SHARDS},
    \"resource_allocation\": { \"cpu\": \"16\", \"memory\": \"64Gi\" }
  }"

echo ""
echo "==> Haji Cloud mesh binding complete."
