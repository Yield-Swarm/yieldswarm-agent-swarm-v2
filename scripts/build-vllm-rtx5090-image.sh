#!/usr/bin/env bash
# Build and optionally push the vLLM RTX 5090 image.
# Usage: ./scripts/build-vllm-rtx5090-image.sh [tag] [--push]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-ghcr.io/yield-swarm/vllm-rtx5090:latest}"
PUSH=0
[[ "${2:-}" == "--push" || "${1:-}" == "--push" ]] && PUSH=1

cd "${REPO_ROOT}/deploy/vllm-rtx5090"
docker build -t "${TAG}" .

if [[ "${PUSH}" == "1" ]]; then
  docker push "${TAG}"
fi

echo "Built ${TAG}"
echo "Deploy: DEPLOY_IMAGE=${TAG} bash scripts/deploy-to-akash.sh deploy deploy/akash-rtx5090-vllm.sdl.yml"
