#!/usr/bin/env bash
# Full Akash Mainnet deployment for dual-purpose Bittensor miner:
# create → bids → lease → manifest → health check.
#
# Ports: 8080 telemetry (Arena), 8091 Bittensor axon
#
# Usage:
#   export VAULT_ADDR=... VAULT_ROLE_ID=... VAULT_SECRET_ID=...
#   export BT_NETUID=1
#   export AKASH_WALLET_MNEMONIC="..."   # or store in Vault yieldswarm/akash
#   ./deploy/akash/deploy-bittensor.sh
#
# Options:
#   --image IMAGE          Container image (default: ghcr.io/yield-swarm/bittensor-miner:latest)
#   --provider ADDRESS     Prefer provider (default: europlots mainnet)
#   --max-bid-uakt N       Max bid price in uakt (default: 8000)
#   --skip-health          Skip post-deploy health probe

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SDL_TEMPLATE="${REPO_ROOT}/deploy/akash-bittensor-miner.sdl.yml"
PS="${PROVIDER_SERVICES_BIN:-provider-services}"
STATE_FILE="${REPO_ROOT}/deploy/.akash-bittensor-deployment.json"

DEPLOY_IMAGE="${DEPLOY_IMAGE:-ghcr.io/yield-swarm/bittensor-miner:latest}"
BT_NETWORK="${BT_NETWORK:-finney}"
BT_WALLET_NAME="${BT_WALLET_NAME:-miner}"
BT_HOTKEY_NAME="${BT_HOTKEY_NAME:-default}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
PREFERRED_PROVIDER="${PREFERRED_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"
PREFERRED_PROVIDER_HOST="${PREFERRED_PROVIDER_HOST:-provider.europlots.com}"
MAX_BID_UAKT="${MAX_BID_UAKT:-8000}"
BID_WAIT_SECS="${BID_WAIT_SECS:-120}"
BID_POLL_INTERVAL="${BID_POLL_INTERVAL:-5}"
SKIP_HEALTH=false

log() { printf '[bittensor-deploy] %s\n' "$*" >&2; }

render_sdl() {
  local template="$1" output="$2"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${VAULT_ADDR} ${VAULT_ROLE_ID} ${VAULT_SECRET_ID} ${VAULT_SKIP_VERIFY} ${DEPLOY_IMAGE} ${BT_NETUID} ${BT_NETWORK} ${BT_WALLET_NAME} ${BT_HOTKEY_NAME} ${OLLAMA_MODEL} ${AKASH_DSEQ} ${AKASH_PROVIDER}' \
      < "${template}" > "${output}"
  else
    python3 - "${template}" "${output}" <<'PY'
import os, sys
text = open(sys.argv[1]).read()
for key in ("VAULT_ADDR", "VAULT_ROLE_ID", "VAULT_SECRET_ID", "VAULT_SKIP_VERIFY",
            "DEPLOY_IMAGE", "BT_NETUID", "BT_NETWORK", "BT_WALLET_NAME", "BT_HOTKEY_NAME",
            "OLLAMA_MODEL", "AKASH_DSEQ", "AKASH_PROVIDER"):
    text = text.replace("${%s}" % key, os.environ.get(key, ""))
open(sys.argv[2], "w").write(text)
PY
  fi
}

usage() {
  sed -n '2,18p' "$0"
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

export PATH="${REPO_ROOT}/bin:${PATH}"
[[ -x "${REPO_ROOT}/bin/provider-services" ]] && PS="${REPO_ROOT}/bin/provider-services"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_ROLE_ID:?Set VAULT_ROLE_ID}"
: "${VAULT_SECRET_ID:?Set VAULT_SECRET_ID}"
: "${BT_NETUID:?Set BT_NETUID}"

if ! command -v "${PS}" >/dev/null 2>&1; then
  log "ERROR: provider-services not found"
  exit 1
fi

# shellcheck source=setup-auth.sh
source "${SCRIPT_DIR}/setup-auth.sh"
configure_akash_auth

BALANCE_JSON="$("${PS}" query bank balances --node "${AKASH_NODE}" "${AKASH_ACCOUNT_ADDRESS}" -o json)"
UAKT="$(echo "${BALANCE_JSON}" | jq -r '[.balances[]? | select(.denom=="uakt") | .amount] | first // "0"')"
if [[ "${UAKT}" -lt 500000 ]]; then
  log "ERROR: balance ${UAKT} uAKT < 500000 (0.5 AKT minimum)"
  log "Fund address: ${AKASH_ACCOUNT_ADDRESS}"
  exit 1
fi
log "Wallet funded: ${UAKT} uAKT — ${AKASH_ACCOUNT_ADDRESS}"

export DEPLOY_IMAGE BT_NETWORK BT_WALLET_NAME BT_HOTKEY_NAME OLLAMA_MODEL
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-false}"
export AKASH_DSEQ="" AKASH_PROVIDER=""

SDL_RENDERED="$(mktemp)"
trap 'rm -f "${SDL_RENDERED}"' EXIT

render_sdl "${SDL_TEMPLATE}" "${SDL_RENDERED}"

log "Validating SDL → manifest"
"${PS}" sdl-to-manifest "${SDL_RENDERED}" -o json >/dev/null

# --- Step 1: Create deployment ---
log "Step 1/4: Creating Bittensor miner deployment (netuid=${BT_NETUID}, image=${DEPLOY_IMAGE})"
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

select_bid() {
  local bids="$1"
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
log "Step 3/4: Creating lease"
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

# Re-render SDL with deployment metadata for telemetry labels
export AKASH_DSEQ="${DSEQ}" AKASH_PROVIDER="${PROVIDER}"
render_sdl "${SDL_TEMPLATE}" "${SDL_RENDERED}"

# --- Step 4: Send manifest ---
log "Step 4/4: Sending manifest"
"${PS}" send-manifest "${SDL_RENDERED}" \
  --dseq "${DSEQ}" \
  --provider "${PROVIDER}" \
  --from "${AKASH_KEY_NAME}" \
  --keyring-backend "${AKASH_KEYRING_BACKEND}" \
  --node "${AKASH_NODE}"

mkdir -p "$(dirname "${STATE_FILE}")"
jq -n \
  --arg dseq "${DSEQ}" \
  --arg provider "${PROVIDER}" \
  --arg owner "${AKASH_ACCOUNT_ADDRESS}" \
  --arg image "${DEPLOY_IMAGE}" \
  --arg price "${BID_PRICE}" \
  --arg netuid "${BT_NETUID}" \
  --arg network "${BT_NETWORK}" \
  --arg host "${PREFERRED_PROVIDER_HOST}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{dseq: $dseq, provider: $provider, owner: $owner, image: $image, bid_uakt: $price,
    bt_netuid: $netuid, bt_network: $network, provider_host: $host, deployed_at: $ts,
    telemetry_port: 8080, axon_port: 8091}' \
  > "${STATE_FILE}"

log "Deployment state written to ${STATE_FILE}"
log ""
log "=== Bittensor deployment complete ==="
log "  dseq:     ${DSEQ}"
log "  provider: ${PROVIDER}"
log "  netuid:   ${BT_NETUID}"
log "  ports:    8080 (telemetry) / 8091 (axon)"
log ""
log "Monitor:  ${SCRIPT_DIR}/monitor-lease.sh --dseq ${DSEQ} --provider ${PROVIDER}"
log "Arena:    arena/index.html?workers=https://<lease-uri>:8080"

if [[ "${SKIP_HEALTH}" == "false" ]]; then
  "${SCRIPT_DIR}/monitor-lease.sh" --wait --dseq "${DSEQ}" --provider "${PROVIDER}" || true
fi
