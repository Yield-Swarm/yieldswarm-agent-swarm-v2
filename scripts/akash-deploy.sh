#!/usr/bin/env bash
set -Eeuo pipefail

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

Production Akash deployment with HashiCorp Vault runtime secret injection.

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
  AUTO_SELECT_BID           Optional: set to 1 to auto-create lease (default: 1 in production).
  AKASH_PROVIDER            Optional: provider override when AUTO_SELECT_BID=1.
  AGENT_SHARD_ID            Optional: shard id 0-119 (default: 0).
  VAULT_ROLE_ID             Optional: pre-minted; auto-minted if VAULT_TOKEN set.
  VAULT_WRAPPED_SECRET_ID   Optional: pre-minted; auto-minted if VAULT_TOKEN set.
  VAULT_ADDR                Optional: Vault server (default: https://vault.yieldswarm.io:8200).
  SKIP_VAULT                Optional: set to 1 to deploy without Vault env injection.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

json_tmp() {
  mktemp -t akash-deploy.XXXXXX.json
}

mint_vault_credentials() {
  if [[ -n "${VAULT_ROLE_ID:-}" && -n "${VAULT_WRAPPED_SECRET_ID:-}" ]]; then
    log "using pre-supplied Vault credentials"
    return 0
  fi

  if [[ "${SKIP_VAULT:-0}" == "1" ]]; then
    log "SKIP_VAULT=1 — deploying without Vault bootstrap env"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [[ -x "${script_dir}/vault-mint-wrap.sh" ]] || fail "vault-mint-wrap.sh not found"

  log "minting wrapped SecretID from Vault"
  eval "$("${script_dir}/vault-mint-wrap.sh")"
  export VAULT_ROLE_ID VAULT_WRAPPED_SECRET_ID
}

build_deploy_env_args() {
  DEPLOY_ENV_ARGS=()
  if [[ "${SKIP_VAULT:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_WRAPPED_SECRET_ID:-}" ]]; then
    fail "Vault credentials required (set VAULT_* or SKIP_VAULT=1)"
  fi
  AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"
  DEPLOY_ENV_ARGS=(
    --env "VAULT_ADDR=${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
    --env "VAULT_ROLE_ID=${VAULT_ROLE_ID}"
    --env "VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}"
    --env "AGENT_SHARD_ID=${AGENT_SHARD_ID}"
  )
}

create_deployment() {
  local sdl_file="$1"
  local output_file="$2"

  log "creating deployment from ${sdl_file}"
  provider-services tx deployment create "${sdl_file}" \
    --from "${AKASH_KEY_NAME}" \
    --node "${AKASH_NODE}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --deposit "${AKASH_DEPOSIT}" \
    --gas "${AKASH_GAS}" \
    --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
    --gas-prices "${AKASH_GAS_PRICES}" \
    "${DEPLOY_ENV_ARGS[@]}" \
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
  provider-services tx market lease create \
    --dseq "${dseq}" \
    --gseq 1 \
    --oseq 1 \
    --provider "${provider}" \
    --from "${AKASH_KEY_NAME}" \
    --node "${AKASH_NODE}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --gas "${AKASH_GAS}" \
    --gas-adjustment "${AKASH_GAS_ADJUSTMENT}" \
    --gas-prices "${AKASH_GAS_PRICES}" \
    --yes \
    --output json > "${output_file}"
}

health_check_worker() {
  local url="$1"
  local attempts="${2:-12}"
  local i=0
  while (( i < attempts )); do
    if curl -fsS --max-time 10 "${url}/healthz" >/dev/null 2>&1; then
      log "worker healthy at ${url}"
      return 0
    fi
    sleep 10
    i=$((i + 1))
  done
  log "worker health check timed out for ${url}"
  return 1
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

  AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
  AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
  AKASH_GAS="${AKASH_GAS:-auto}"
  AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.4}"
  AKASH_GAS_PRICES="${AKASH_GAS_PRICES:-0.025uakt}"
  AKASH_DEPOSIT="${AKASH_DEPOSIT:-5000000uakt}"
  AKASH_BID_WAIT_SECONDS="${AKASH_BID_WAIT_SECONDS:-180}"
  AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
  AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"

  AKASH_ACCOUNT_ADDRESS="${AKASH_ACCOUNT_ADDRESS:-$(provider-services keys show "${AKASH_KEY_NAME}" -a 2>/dev/null || true)}"
  [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]] || fail "unable to resolve AKASH_ACCOUNT_ADDRESS from key ${AKASH_KEY_NAME}"

  mint_vault_credentials
  build_deploy_env_args

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
    provider-services send-manifest "${SDL_FILE}" \
      --dseq "${DSEQ}" \
      --provider "${provider}" \
      --from "${AKASH_KEY_NAME}" \
      --node "${AKASH_NODE}"

    # Auto-healing: verify worker health after manifest
    lease_uri="$(provider-services lease-status \
      --dseq "${DSEQ}" --gseq 1 --oseq 1 \
      --provider "${provider}" \
      --node "${AKASH_NODE}" 2>/dev/null \
      | jq -r '.services.worker.uris[0] // empty' || true)"
    if [[ -n "${lease_uri}" ]]; then
      health_check_worker "${lease_uri}" || log "WARN: initial health check failed — run deploy/akash/auto-heal.sh"
    fi
  else
    log "AUTO_SELECT_BID disabled. Review bids and create lease manually for dseq=${DSEQ}"
  fi

  cat <<EOF
Deployment summary:
  owner:     ${AKASH_ACCOUNT_ADDRESS}
  dseq:      ${DSEQ}
  chain:     ${AKASH_CHAIN_ID}
  node:      ${AKASH_NODE}
  sdl:       ${SDL_FILE}
  shard:     ${AGENT_SHARD_ID}
  vault:     $([[ "${SKIP_VAULT:-0}" == "1" ]] && echo "skipped" || echo "injected")
EOF
}

main "$@"
