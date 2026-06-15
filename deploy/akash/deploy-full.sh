#!/usr/bin/env bash
# Full Akash Mainnet deployment: create → bids → lease → manifest → health check.
#
# JWT auth (AEP-64): provider-services auto-mints tokens — no manual AKASH_JWT needed.
# Secrets: wallet + Vault AppRole pulled at deploy time (never hardcoded in SDL).
#
# Usage:
#   export VAULT_ADDR=... VAULT_ROLE_ID=... VAULT_SECRET_ID=...
#   export AKASH_WALLET_MNEMONIC="..."   # or store in Vault yieldswarm/akash
#   ./deploy/akash/deploy-full.sh
#
# Options:
#   --image IMAGE          Container image (default: yieldswarm agentswarm image)
#   --provider ADDRESS     Prefer provider (default: europlots mainnet)
#   --max-bid-uakt N       Max bid price in uakt (default: 5000)
#   --skip-health          Skip post-deploy health probe

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/deploy-swarm-monolith.yaml"
PS="${PROVIDER_SERVICES_BIN:-provider-services}"

# Defaults
DEPLOY_IMAGE="${DEPLOY_IMAGE:-ghcr.io/yield-swarm/agentswarm-akash:latest}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
PREFERRED_PROVIDER="${PREFERRED_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"
PREFERRED_PROVIDER_HOST="${PREFERRED_PROVIDER_HOST:-provider.europlots.com}"
MAX_BID_UAKT="${MAX_BID_UAKT:-5000}"
BID_WAIT_SECS="${BID_WAIT_SECS:-120}"
BID_POLL_INTERVAL="${BID_POLL_INTERVAL:-5}"
SKIP_HEALTH=false

log() { printf '[deploy] %s\n' "$*" >&2; }

render_sdl() {
  local template="$1" output="$2"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID} ${VAULT_SKIP_VERIFY} ${DEPLOY_IMAGE} ${CONTAINER_PORT}' \
      < "${template}" > "${output}"
  else
    python3 - "${template}" "${output}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for key in ("VAULT_ADDR", "VAULT_ROLE_ID", "VAULT_SECRET_ID", "VAULT_SKIP_VERIFY",
            "DEPLOY_IMAGE", "CONTAINER_PORT"):
    text = text.replace("${%s}" % key, os.environ.get(key, ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

usage() {
  sed -n '2,20p' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) DEPLOY_IMAGE="$2"; shift 2 ;;
    --provider) PREFERRED_PROVIDER="$2"; shift 2 ;;
    --max-bid-uakt) MAX_BID_UAKT="$2"; shift 2 ;;
    --skip-health) SKIP_HEALTH=true; shift ;;
    -h|--help) usage 0 ;;
    *) log "Unknown option: $1"; usage 1 ;;
  esac
done

# Auto-detect common public images that listen on :80
case "${DEPLOY_IMAGE}" in
  nginx*|*/nginx*) CONTAINER_PORT=80 ;;
esac

export PATH="${REPO_ROOT}/bin:${PATH}"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"

if ! command -v "${PS}" >/dev/null 2>&1; then
  if [[ -x "${REPO_ROOT}/bin/provider-services" ]]; then
    PS="${REPO_ROOT}/bin/provider-services"
  else
    log "ERROR: provider-services not found"
    exit 1
  fi
fi

# shellcheck source=setup-auth.sh
source "${SCRIPT_DIR}/setup-auth.sh"
configure_akash_auth

# Verify funded wallet
BALANCE_JSON="$("${PS}" query bank balances --node "${AKASH_NODE}" "${AKASH_ACCOUNT_ADDRESS}" -o json)"
UAKT="$(echo "${BALANCE_JSON}" | jq -r '[.balances[]? | select(.denom=="uakt") | .amount] | first // "0"')"
if [[ "${UAKT}" -lt 500000 ]]; then
  log "ERROR: balance ${UAKT} uAKT < 500000 (0.5 AKT minimum)"
  log "Fund address: ${AKASH_ACCOUNT_ADDRESS}"
  exit 1
fi
log "Wallet funded: ${UAKT} uAKT — ${AKASH_ACCOUNT_ADDRESS}"

# Render SDL
export DEPLOY_IMAGE CONTAINER_PORT
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
SDL_RENDERED="$(mktemp)"
trap 'rm -f "${SDL_RENDERED}"' EXIT

render_sdl "${SDL_TEMPLATE}" "${SDL_RENDERED}"

log "Validating SDL → manifest"
"${PS}" sdl-to-manifest "${SDL_RENDERED}" -o json >/dev/null

# --- Step 1: Create deployment ---
log "Step 1/4: Creating deployment on ${AKASH_CHAIN_ID}"
TX_JSON="$("${PS}" tx deployment create "${SDL_RENDERED}" \
  --from "${AKASH_KEY_NAME}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas-prices "${AKASH_GAS_PRICES}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  -y --output json)"

DSEQ="$(echo "${TX_JSON}" | jq -r '
  [.events[]? | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[]? |
   select(.key=="dseq" or .key=="DSEQ") | .value][0] // empty')"

if [[ -z "${DSEQ}" ]]; then
  # Fallback: parse from logs (older output format)
  DSEQ="$(echo "${TX_JSON}" | jq -r '
    [.logs[]?.events[]? | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[]? |
     select(.key=="dseq") | .value][0] // empty')"
fi

if [[ -z "${DSEQ}" ]]; then
  log "ERROR: could not parse dseq from deployment tx"
  echo "${TX_JSON}" | jq '.' >&2
  exit 1
fi
log "Deployment created: dseq=${DSEQ}"

# --- Step 2: Query bids ---
log "Step 2/4: Waiting for bids (up to ${BID_WAIT_SECS}s)"
BIDS_JSON=""
elapsed=0
while [[ "${elapsed}" -lt "${BID_WAIT_SECS}" ]]; do
  BIDS_JSON="$("${PS}" query market bid list \
    --owner "${AKASH_ACCOUNT_ADDRESS}" \
    --dseq "${DSEQ}" \
    --node "${AKASH_NODE}" \
    -o json 2>/dev/null || echo '{"bids":[]}')"

  BID_COUNT="$(echo "${BIDS_JSON}" | jq '.bids | length')"
  if [[ "${BID_COUNT}" -gt 0 ]]; then
    log "Received ${BID_COUNT} bid(s)"
    break
  fi
  sleep "${BID_POLL_INTERVAL}"
  elapsed=$((elapsed + BID_POLL_INTERVAL))
done

if [[ "$(echo "${BIDS_JSON}" | jq '.bids | length')" -eq 0 ]]; then
  log "ERROR: no bids received within ${BID_WAIT_SECS}s"
  exit 1
fi

# --- Select bid: prefer europlots, else lowest price under max ---
select_bid() {
  local bids="$1"
  # 1) Exact preferred provider address (europlots mainnet)
  local selected
  selected="$(echo "${bids}" | jq -r --arg p "${PREFERRED_PROVIDER}" --arg max "${MAX_BID_UAKT}" '
    [.bids[]? | select(.bid.bid_id.provider == $p) |
     select((.bid.price.amount | tonumber) <= ($max | tonumber))] |
    sort_by(.bid.price.amount | tonumber) | .[0] // empty |
    @base64')"
  if [[ -n "${selected}" ]]; then
    echo "${selected}" | base64 -d
    return
  fi
  # 2) Lowest price bid under max
  echo "${bids}" | jq -r --arg max "${MAX_BID_UAKT}" '
    [.bids[]? | select((.bid.price.amount | tonumber) <= ($max | tonumber))] |
    sort_by(.bid.price.amount | tonumber) | .[0] // empty'
}

SELECTED_BID="$(select_bid "${BIDS_JSON}")"
if [[ -z "${SELECTED_BID}" || "${SELECTED_BID}" == "null" ]]; then
  log "ERROR: no bids under ${MAX_BID_UAKT} uAKT"
  echo "${BIDS_JSON}" | jq '[.bids[]? | {provider: .bid.bid_id.provider, price: .bid.price.amount}]' >&2
  exit 1
fi

PROVIDER="$(echo "${SELECTED_BID}" | jq -r '.bid.bid_id.provider')"
GSEQ="$(echo "${SELECTED_BID}" | jq -r '.bid.bid_id.gseq')"
OSEQ="$(echo "${SELECTED_BID}" | jq -r '.bid.bid_id.oseq')"
BID_PRICE="$(echo "${SELECTED_BID}" | jq -r '.bid.price.amount')"

log "Selected bid: provider=${PROVIDER} gseq=${GSEQ} oseq=${OSEQ} price=${BID_PRICE} uAKT"
if [[ "${PROVIDER}" == "${PREFERRED_PROVIDER}" ]]; then
  log "Using preferred provider (${PREFERRED_PROVIDER_HOST})"
fi

# --- Step 3: Create lease ---
log "Step 3/4: Creating lease (JWT auth for manifest send)"
"${PS}" tx market lease create \
  --dseq "${DSEQ}" \
  --gseq "${GSEQ}" \
  --oseq "${OSEQ}" \
  --provider "${PROVIDER}" \
  --from "${AKASH_KEY_NAME}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --gas-prices "${AKASH_GAS_PRICES}" \
  --gas "${AKASH_GAS}" \
  --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
  -y >/dev/null

log "Lease created"

# --- Step 4: Send manifest ---
log "Step 4/4: Sending manifest (provider-services auto-JWT)"
"${PS}" send-manifest "${SDL_RENDERED}" \
  --dseq "${DSEQ}" \
  --provider "${PROVIDER}" \
  --from "${AKASH_KEY_NAME}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}"

# Persist deployment state (no secrets)
STATE_FILE="${REPO_ROOT}/deploy/.akash-deployment.json"
mkdir -p "$(dirname "${STATE_FILE}")"
jq -n \
  --arg dseq "${DSEQ}" \
  --arg provider "${PROVIDER}" \
  --arg owner "${AKASH_ACCOUNT_ADDRESS}" \
  --arg image "${DEPLOY_IMAGE}" \
  --arg price "${BID_PRICE}" \
  --arg host "${PREFERRED_PROVIDER_HOST}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{dseq: $dseq, provider: $provider, owner: $owner, image: $image, bid_uakt: $price, provider_host: $host, deployed_at: $ts}' \
  > "${STATE_FILE}"

log "Deployment state written to ${STATE_FILE}"
log ""
log "=== Deployment complete ==="
log "  dseq:     ${DSEQ}"
log "  provider: ${PROVIDER}"
log "  owner:    ${AKASH_ACCOUNT_ADDRESS}"
log "  image:    ${DEPLOY_IMAGE}"
log ""
log "Monitor:  ${SCRIPT_DIR}/monitor-lease.sh"
log "Logs:     ${PS} lease-logs --dseq ${DSEQ} --provider ${PROVIDER} --from ${AKASH_KEY_NAME} --keyring-backend ${AKASH_KEYRING_BACKEND}"
log "Status:   ${PS} lease-status --dseq ${DSEQ} --provider ${PROVIDER} --from ${AKASH_KEY_NAME} --keyring-backend ${AKASH_KEYRING_BACKEND}"

if [[ "${SKIP_HEALTH}" == "false" ]]; then
  "${SCRIPT_DIR}/monitor-lease.sh" --wait --dseq "${DSEQ}" --provider "${PROVIDER}" || true
fi
