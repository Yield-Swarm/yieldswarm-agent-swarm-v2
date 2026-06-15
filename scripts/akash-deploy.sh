#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib/akash-auth.sh"
# shellcheck disable=SC1091
source "${HERE}/lib/vault-akash-bootstrap.sh"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[$(timestamp)] [akash-deploy] $*"
}

fail() {
  echo "[$(timestamp)] [akash-deploy] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/akash-deploy.sh [SDL_FILE]

Environment variables:
  AKASH_KEY_NAME            Required: local key name used to sign transactions.
  AKASH_ACCOUNT_ADDRESS     Optional: wallet address (auto-discovered from key if omitted).
  AKASH_NODE                Optional: RPC endpoint (default: https://rpc.akashnet.net:443).
  AKASH_CHAIN_ID            Optional: chain id (default: akashnet-2).
  AKASH_GAS                 Optional: gas setting (default: auto).
  AKASH_GAS_ADJUSTMENT      Optional: gas adjustment (default: 1.4).
  AKASH_GAS_PRICES          Optional: gas prices (default: 0.025uakt).
  AKASH_DEPOSIT             Optional: deployment deposit (default: 5000000uakt).
  AKASH_BID_WAIT_SECONDS    Optional: how long to wait for bids (default: 180).
  AUTO_SELECT_BID           Optional: set to 1 to auto-create lease for lowest-price bid.
  AKASH_PROVIDER            Optional: provider to use when AUTO_SELECT_BID=1 (overrides auto-pick).
  AKASH_KEYRING_BACKEND     Keyring backend (default: test). Use os in production.
  AKASH_JWT                 Optional: pre-generated JWT for send-manifest (CI/CD).
  AKASH_JWT_FILE            Optional: path to JWT file for send-manifest.
  AKASH_AUTH_METHOD         keyring (default) or jwt — see docs/AKASH_AUTH.md
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

json_tmp() {
  mktemp -t akash-deploy.XXXXXX.json
}

create_deployment() {
  local sdl_file="$1"
  local output_file="$2"
  local vault_env_args=()

  if vault_maybe_prepare_for_sdl "$sdl_file" "${VAULT_AKASH_ROLE:-akash-runtime}" 2>/dev/null; then
    while IFS= read -r flag; do
      [[ -n "$flag" ]] && vault_env_args+=("$flag")
    done < <(vault_akash_env_flags)
  fi

  log "creating deployment from ${sdl_file}"
  # shellcheck disable=SC2046
  provider-services tx deployment create "${sdl_file}" \
    $(akash_tx_flags) \
    --deposit "${AKASH_DEPOSIT}" \
    "${vault_env_args[@]}" \
    --yes \
    --output json > "${output_file}"
}

extract_dseq() {
  local deployment_json="$1"
  jq -r '.logs[0].events[]? | select(.type=="akash.v1") | .attributes[]? | select(.key=="dseq") | .value' "${deployment_json}" | head -n 1
}

wait_for_bids() {
  local dseq="$1"
  local bids_file="$2"
  local elapsed=0
  local sleep_seconds=10
  local bid_count=0

  while (( elapsed < AKASH_BID_WAIT_SECONDS )); do
    provider-services query market bid list \
      --owner "${AKASH_ACCOUNT_ADDRESS}" \
      --dseq "${dseq}" \
      --state open \
      --node "${AKASH_NODE}" \
      --output json > "${bids_file}"

    bid_count="$(jq '.bids | length' "${bids_file}")"
    if [[ "${bid_count}" -gt 0 ]]; then
      log "received ${bid_count} open bid(s)"
      return 0
    fi

    log "no bids yet for dseq=${dseq}, waiting ${sleep_seconds}s"
    sleep "${sleep_seconds}"
    elapsed=$((elapsed + sleep_seconds))
  done

  return 1
}

select_provider() {
  local bids_file="$1"

  if [[ -n "${AKASH_PROVIDER:-}" ]]; then
    echo "${AKASH_PROVIDER}"
    return 0
  fi

  jq -r '.bids | sort_by((.bid.price.amount|tonumber)) | .[0].bid.bid_id.provider // empty' "${bids_file}"
}

create_lease() {
  local dseq="$1"
  local provider="$2"
  local output_file="$3"

  log "creating lease for dseq=${dseq} with provider=${provider}"
  # shellcheck disable=SC2046
  provider-services tx market lease create \
    --dseq "${dseq}" \
    --gseq 1 \
    --oseq 1 \
    --provider "${provider}" \
    $(akash_tx_flags) \
    --yes \
    --output json > "${output_file}"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_cmd provider-services
  require_cmd jq

  SDL_FILE="${1:-deploy/deploy-swarm-monolith.yaml}"
  [[ -f "${SDL_FILE}" ]] || fail "SDL file not found: ${SDL_FILE}"

  AKASH_KEY_NAME="${AKASH_KEY_NAME:-}"
  [[ -n "${AKASH_KEY_NAME}" ]] || fail "AKASH_KEY_NAME is required"

  AKASH_DEPOSIT="${AKASH_DEPOSIT:-5000000uakt}"
  AKASH_BID_WAIT_SECONDS="${AKASH_BID_WAIT_SECONDS:-180}"
  AUTO_SELECT_BID="${AUTO_SELECT_BID:-0}"
  akash__require_env

  AKASH_ACCOUNT_ADDRESS="${AKASH_ACCOUNT_ADDRESS:-$(akash_account_address || true)}"
  [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]] || fail "unable to resolve AKASH_ACCOUNT_ADDRESS from key ${AKASH_KEY_NAME}"

  deployment_json="$(json_tmp)"
  bids_json="$(json_tmp)"
  lease_json="$(json_tmp)"
  trap 'rm -f "${deployment_json}" "${bids_json}" "${lease_json}"' EXIT

  create_deployment "${SDL_FILE}" "${deployment_json}"
  DSEQ="$(extract_dseq "${deployment_json}")"
  [[ -n "${DSEQ}" ]] || fail "failed to parse dseq from deployment transaction output"
  log "deployment created with dseq=${DSEQ}"

  if ! wait_for_bids "${DSEQ}" "${bids_json}"; then
    fail "no provider bids found within ${AKASH_BID_WAIT_SECONDS}s (dseq=${DSEQ})"
  fi

  if [[ "${AUTO_SELECT_BID}" == "1" ]]; then
    provider="$(select_provider "${bids_json}")"
    [[ -n "${provider}" ]] || fail "unable to select provider from open bids"
    create_lease "${DSEQ}" "${provider}" "${lease_json}"
    log "lease created successfully for provider=${provider}"

    log "sending manifest to selected provider"
    # shellcheck disable=SC2046
    provider-services send-manifest "${SDL_FILE}" \
      --dseq "${DSEQ}" \
      --provider "${provider}" \
      --node "${AKASH_NODE}" \
      $(akash_manifest_auth_flags)
  else
    log "AUTO_SELECT_BID disabled. Review bids and create lease manually for dseq=${DSEQ}"
  fi

  cat <<EOF
Deployment summary:
  owner:    ${AKASH_ACCOUNT_ADDRESS}
  dseq:     ${DSEQ}
  chain:    ${AKASH_CHAIN_ID}
  node:     ${AKASH_NODE}
  sdl:      ${SDL_FILE}
EOF
}

main "$@"
