#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDL_FILE="${ROOT_DIR}/deploy/deploy-swarm-monolith.yaml"
STATE_DIR="${ROOT_DIR}/.akash"
DEPLOYMENT_FILE="${STATE_DIR}/deployment.json"
BIDS_FILE="${STATE_DIR}/bids.json"
LEASE_FILE="${STATE_DIR}/lease.json"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

export AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
export AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
export AKASH_GAS="${AKASH_GAS:-auto}"
export AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.25}"
export AKASH_GAS_PRICES="${AKASH_GAS_PRICES:-0.025uakt}"
export AKASH_SIGN_MODE="${AKASH_SIGN_MODE:-amino-json}"
export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm-admin}"

for required_cmd in provider-services jq; do
  if ! command -v "${required_cmd}" >/dev/null 2>&1; then
    echo "Missing dependency: ${required_cmd}" >&2
    exit 1
  fi
done

if [[ ! -f "${SDL_FILE}" ]]; then
  echo "SDL file not found: ${SDL_FILE}" >&2
  exit 1
fi

mkdir -p "${STATE_DIR}"

OWNER="$(provider-services keys show "${AKASH_KEY_NAME}" -a)"
echo "Using owner address: ${OWNER}"

provider-services tx deployment create "${SDL_FILE}" \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  --gas-prices "${AKASH_GAS_PRICES}" \
  --sign-mode "${AKASH_SIGN_MODE}" \
  --yes \
  --output json | tee "${DEPLOYMENT_FILE}" >/dev/null

DSEQ="$(jq -r '[.. | .dseq? | strings] | first // empty' "${DEPLOYMENT_FILE}")"
if [[ -z "${DSEQ}" ]]; then
  echo "Failed to extract DSEQ from deployment response." >&2
  exit 1
fi
echo "Deployment sequence (dseq): ${DSEQ}"

provider-services query market bid list \
  --owner "${OWNER}" \
  --dseq "${DSEQ}" \
  --node "${AKASH_NODE}" \
  --output json | tee "${BIDS_FILE}" >/dev/null

if [[ "${AKASH_PROVIDER:-}" == "" ]]; then
  echo "Set AKASH_PROVIDER in your environment after reviewing ${BIDS_FILE}."
  echo "Example:"
  echo "  export AKASH_PROVIDER=\$(jq -r '.bids[0].bid.lease_id.provider' ${BIDS_FILE})"
  exit 1
fi

provider-services tx market lease create \
  --dseq "${DSEQ}" \
  --gseq 1 \
  --oseq 1 \
  --provider "${AKASH_PROVIDER}" \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  --gas-prices "${AKASH_GAS_PRICES}" \
  --sign-mode "${AKASH_SIGN_MODE}" \
  --yes \
  --output json | tee "${LEASE_FILE}" >/dev/null

provider-services send-manifest "${SDL_FILE}" \
  --dseq "${DSEQ}" \
  --gseq 1 \
  --oseq 1 \
  --provider "${AKASH_PROVIDER}" \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --yes

echo "Lease created. Inspect status with:"
echo "provider-services lease-status --dseq ${DSEQ} --gseq 1 --oseq 1 --provider ${AKASH_PROVIDER} --node ${AKASH_NODE}"
