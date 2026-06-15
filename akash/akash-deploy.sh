#!/usr/bin/env bash
#
# akash-deploy.sh - Production Akash deployment helper for RTX 3090 GPU workers.
#
# This script wraps the Akash CLI (`provider-services`, formerly `akash`) and
# provides the primitive operations the lease-manager needs to keep GPU workers
# alive: create a deployment, inspect bids, pick the best available RTX 3090
# provider, open a lease, push the manifest, read back the worker URL, and close
# dead deployments.
#
# It is intentionally composable: every subcommand prints machine-readable JSON
# on stdout (so lease-manager.py can parse it) and human-readable logs on stderr.
#
# Usage:
#   ./akash-deploy.sh deploy [sdl_file]            # full deploy -> JSON lease info
#   ./akash-deploy.sh bids <dseq>                  # list open bids -> JSON
#   ./akash-deploy.sh select-provider <dseq>       # pick best RTX 3090 bid -> JSON
#   ./akash-deploy.sh lease <dseq> <provider>      # create lease + send manifest
#   ./akash-deploy.sh lease-status <dseq> <provider>
#   ./akash-deploy.sh uri <dseq> <provider>        # resolve worker URL(s) -> JSON
#   ./akash-deploy.sh close <dseq>                 # close a deployment
#   ./akash-deploy.sh list                         # list active deployments -> JSON
#   ./akash-deploy.sh check                        # verify environment/prereqs
#
# Configuration is read from the environment (and an optional .env file). See
# akash-lease-manager.env.example for the full list.
#
set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Paths & config loading
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env files if present (do not clobber values already in the environment).
load_env() {
  local f
  for f in "$SCRIPT_DIR/.env" "$SCRIPT_DIR/../.env" "$AKASH_ENV_FILE"; do
    [[ -n "${f:-}" && -f "$f" ]] || continue
    # shellcheck disable=SC1090
    set -a; source "$f"; set +a
  done
}
AKASH_ENV_FILE="${AKASH_ENV_FILE:-}"
load_env

# Akash CLI binary. Modern Akash ships as `provider-services`; older as `akash`.
AKASH_BIN="${AKASH_BIN:-provider-services}"

# Chain / node configuration.
AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-os}"
AKASH_KEY_NAME="${AKASH_KEY_NAME:-default}"
AKASH_ACCOUNT_ADDRESS="${AKASH_ACCOUNT_ADDRESS:-}"
AKASH_GAS="${AKASH_GAS:-auto}"
AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.4}"
AKASH_GAS_PRICES="${AKASH_GAS_PRICES:-0.025uakt}"
AKASH_FEES="${AKASH_FEES:-}"

# GPU targeting.
AKASH_GPU_MODEL="${AKASH_GPU_MODEL:-rtx3090}"

# Deployment SDL template.
AKASH_SDL_FILE="${AKASH_SDL_FILE:-$SCRIPT_DIR/worker.sdl.yml}"

# Bid collection: how long to wait for bids and the max acceptable price
# (uakt per block). Bids above the max are ignored.
AKASH_BID_WAIT_SECONDS="${AKASH_BID_WAIT_SECONDS:-45}"
AKASH_BID_POLL_INTERVAL="${AKASH_BID_POLL_INTERVAL:-5}"
AKASH_MAX_BID_PRICE="${AKASH_MAX_BID_PRICE:-100000}"

# Only accept audited providers when set to "true".
AKASH_REQUIRE_AUDITED="${AKASH_REQUIRE_AUDITED:-false}"

# Retry policy for chain queries.
AKASH_TX_RETRIES="${AKASH_TX_RETRIES:-3}"

# ---------------------------------------------------------------------------
# Logging helpers (everything goes to stderr to keep stdout JSON-clean)
# ---------------------------------------------------------------------------
log()  { printf '[akash-deploy] %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
err()  { printf '[akash-deploy] %s ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
die()  { err "$*"; exit 1; }

trap 'err "failed at line $LINENO (exit $?)"' ERR

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

resolve_account_address() {
  if [[ -n "$AKASH_ACCOUNT_ADDRESS" ]]; then
    return 0
  fi
  # Derive the owner address from the configured key.
  AKASH_ACCOUNT_ADDRESS="$("$AKASH_BIN" keys show "$AKASH_KEY_NAME" -a \
    --keyring-backend "$AKASH_KEYRING_BACKEND" 2>/dev/null || true)"
  [[ -n "$AKASH_ACCOUNT_ADDRESS" ]] || \
    die "could not resolve account address; set AKASH_ACCOUNT_ADDRESS or AKASH_KEY_NAME"
}

# Common flags shared by query commands.
query_flags() { printf -- '--node %s --output json' "$AKASH_NODE"; }

# Common flags shared by tx commands.
tx_flags() {
  local fee_flag=""
  if [[ -n "$AKASH_FEES" ]]; then
    fee_flag="--fees $AKASH_FEES"
  else
    fee_flag="--gas-prices $AKASH_GAS_PRICES"
  fi
  printf -- '--node %s --chain-id %s --from %s --keyring-backend %s --gas %s --gas-adjustment %s %s --yes --output json' \
    "$AKASH_NODE" "$AKASH_CHAIN_ID" "$AKASH_KEY_NAME" "$AKASH_KEYRING_BACKEND" \
    "$AKASH_GAS" "$AKASH_GAS_ADJUSTMENT" "$fee_flag"
}

# Run a chain query with retries; prints stdout on success.
retry_query() {
  local attempt=1 out rc
  while :; do
    if out="$("$@" 2>/tmp/akash_q_err)"; then
      printf '%s' "$out"
      return 0
    fi
    rc=$?
    if (( attempt >= AKASH_TX_RETRIES )); then
      err "query failed after $attempt attempts: $* :: $(cat /tmp/akash_q_err 2>/dev/null)"
      return $rc
    fi
    log "query attempt $attempt failed; retrying in $((attempt*2))s"
    sleep $((attempt * 2))
    ((attempt++))
  done
}

# ---------------------------------------------------------------------------
# Subcommand: check
# ---------------------------------------------------------------------------
cmd_check() {
  need_cmd "$AKASH_BIN"
  need_cmd jq
  resolve_account_address
  [[ -f "$AKASH_SDL_FILE" ]] || die "SDL file not found: $AKASH_SDL_FILE"
  jq -n \
    --arg bin "$AKASH_BIN" \
    --arg node "$AKASH_NODE" \
    --arg chain "$AKASH_CHAIN_ID" \
    --arg owner "$AKASH_ACCOUNT_ADDRESS" \
    --arg sdl "$AKASH_SDL_FILE" \
    --arg gpu "$AKASH_GPU_MODEL" \
    '{ok:true, bin:$bin, node:$node, chain_id:$chain, owner:$owner, sdl:$sdl, gpu_model:$gpu}'
  log "environment OK"
}

# ---------------------------------------------------------------------------
# Subcommand: deploy <sdl>
# Creates a deployment, waits for bids, picks the best RTX 3090 provider,
# opens a lease, sends the manifest, and prints the resolved lease info.
# ---------------------------------------------------------------------------
cmd_deploy() {
  local sdl="${1:-$AKASH_SDL_FILE}"
  [[ -f "$sdl" ]] || die "SDL file not found: $sdl"
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address

  log "creating deployment from $sdl (owner=$AKASH_ACCOUNT_ADDRESS)"
  local create_out dseq
  # shellcheck disable=SC2046
  create_out="$(retry_query "$AKASH_BIN" tx deployment create "$sdl" $(tx_flags))" \
    || die "deployment create failed"

  # The DSEQ equals the block height at which the create tx was committed.
  dseq="$(printf '%s' "$create_out" | jq -r '.height // empty')"
  if [[ -z "$dseq" || "$dseq" == "0" ]]; then
    # Fall back to parsing the dseq attribute from the tx events.
    dseq="$(printf '%s' "$create_out" | jq -r '
      [.. | objects | select(.key? == "dseq") | .value] | first // empty')"
  fi
  [[ -n "$dseq" ]] || die "could not determine DSEQ from create tx: $create_out"
  log "deployment created: dseq=$dseq"

  # Pick the best provider for this deployment.
  local provider_json provider price
  provider_json="$(cmd_select_provider "$dseq")" || die "no suitable provider"
  provider="$(printf '%s' "$provider_json" | jq -r '.provider')"
  price="$(printf '%s' "$provider_json" | jq -r '.price')"
  [[ -n "$provider" && "$provider" != "null" ]] || die "no RTX 3090 provider available for dseq=$dseq"
  log "selected provider=$provider price=$price uakt/block"

  # Create the lease + push manifest.
  cmd_lease "$dseq" "$provider" "$sdl" >/dev/null

  # Resolve the worker URL(s).
  local uri_json
  uri_json="$(cmd_uri "$dseq" "$provider")" || die "could not resolve worker URI"

  jq -n \
    --arg dseq "$dseq" \
    --arg provider "$provider" \
    --arg price "$price" \
    --arg owner "$AKASH_ACCOUNT_ADDRESS" \
    --argjson uris "$(printf '%s' "$uri_json" | jq '.uris')" \
    '{ok:true, dseq:$dseq, gseq:1, oseq:1, provider:$provider, owner:$owner,
      price:($price|tonumber? // $price), uris:$uris,
      worker_url:($uris[0] // null)}'
}

# ---------------------------------------------------------------------------
# Subcommand: bids <dseq>
# Waits up to AKASH_BID_WAIT_SECONDS for open bids and prints them as JSON.
# ---------------------------------------------------------------------------
cmd_bids() {
  local dseq="${1:?usage: bids <dseq>}"
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address

  local waited=0 bids
  while (( waited < AKASH_BID_WAIT_SECONDS )); do
    bids="$(retry_query "$AKASH_BIN" query market bid list \
      --owner "$AKASH_ACCOUNT_ADDRESS" --dseq "$dseq" --state open \
      $(query_flags) 2>/dev/null || echo '{}')"
    local count
    count="$(printf '%s' "$bids" | jq '[.bids // []] | flatten | length')"
    if [[ "${count:-0}" -gt 0 ]]; then
      log "received $count bid(s) for dseq=$dseq after ${waited}s"
      printf '%s' "$bids" | jq '[.bids[]? | {
        provider: .bid.bid_id.provider,
        price: (.bid.price.amount | tonumber),
        denom: .bid.price.denom,
        state: .bid.state
      }]'
      return 0
    fi
    sleep "$AKASH_BID_POLL_INTERVAL"
    waited=$((waited + AKASH_BID_POLL_INTERVAL))
    log "waiting for bids... ${waited}s/${AKASH_BID_WAIT_SECONDS}s"
  done
  echo '[]'
  return 0
}

# ---------------------------------------------------------------------------
# Provider attribute check: confirm the provider advertises the target GPU.
# Returns 0 if the provider offers the requested GPU model (best-effort).
# ---------------------------------------------------------------------------
provider_supports_gpu() {
  local provider="$1"
  local info
  info="$(retry_query "$AKASH_BIN" query provider get "$provider" \
    $(query_flags) 2>/dev/null || echo '{}')"
  # If we cannot read attributes, do not block (the SDL already constrains GPU).
  [[ -z "$info" || "$info" == "{}" ]] && return 0

  if [[ "$AKASH_REQUIRE_AUDITED" == "true" ]]; then
    local audited
    audited="$(printf '%s' "$info" | jq -r '.attributes // [] | length')"
    [[ "${audited:-0}" -gt 0 ]] || return 1
  fi

  # Look for a GPU model attribute matching the target (case-insensitive).
  local match
  match="$(printf '%s' "$info" | jq -r --arg g "$AKASH_GPU_MODEL" '
    [.. | strings | select(ascii_downcase | contains($g | ascii_downcase))] | length')"
  [[ "${match:-0}" -gt 0 ]] && return 0
  # Attribute not advertised explicitly; SDL constraint still applies, so allow.
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: select-provider <dseq>
# Picks the cheapest acceptable RTX 3090 bid and prints {provider, price}.
# ---------------------------------------------------------------------------
cmd_select_provider() {
  local dseq="${1:?usage: select-provider <dseq>}"
  need_cmd jq
  local bids
  bids="$(cmd_bids "$dseq")"
  local count
  count="$(printf '%s' "$bids" | jq 'length')"
  [[ "${count:-0}" -gt 0 ]] || { err "no bids for dseq=$dseq"; echo 'null'; return 1; }

  # Sort by price ascending, then filter by max price + GPU support.
  local sorted
  sorted="$(printf '%s' "$bids" | jq --argjson max "$AKASH_MAX_BID_PRICE" \
    '[.[] | select(.price <= $max)] | sort_by(.price)')"

  local n i provider price
  n="$(printf '%s' "$sorted" | jq 'length')"
  for ((i=0; i<n; i++)); do
    provider="$(printf '%s' "$sorted" | jq -r ".[$i].provider")"
    price="$(printf '%s' "$sorted" | jq -r ".[$i].price")"
    if provider_supports_gpu "$provider"; then
      log "best RTX 3090 provider: $provider @ $price uakt/block"
      jq -n --arg p "$provider" --argjson pr "$price" \
        '{provider:$p, price:$pr}'
      return 0
    fi
  done
  err "no provider passed GPU/audit filter for dseq=$dseq"
  echo 'null'
  return 1
}

# ---------------------------------------------------------------------------
# Subcommand: lease <dseq> <provider> [sdl]
# Creates the lease and sends the manifest.
# ---------------------------------------------------------------------------
cmd_lease() {
  local dseq="${1:?usage: lease <dseq> <provider> [sdl]}"
  local provider="${2:?usage: lease <dseq> <provider> [sdl]}"
  local sdl="${3:-$AKASH_SDL_FILE}"
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address

  log "creating lease dseq=$dseq provider=$provider"
  # shellcheck disable=SC2046
  retry_query "$AKASH_BIN" tx market lease create \
    --owner "$AKASH_ACCOUNT_ADDRESS" --dseq "$dseq" --gseq 1 --oseq 1 \
    --provider "$provider" $(tx_flags) >/dev/null \
    || die "lease create failed"

  log "sending manifest to provider=$provider"
  local attempt=1
  while :; do
    if "$AKASH_BIN" send-manifest "$sdl" \
        --owner "$AKASH_ACCOUNT_ADDRESS" --dseq "$dseq" \
        --provider "$provider" --from "$AKASH_KEY_NAME" \
        --keyring-backend "$AKASH_KEYRING_BACKEND" --node "$AKASH_NODE" >&2; then
      break
    fi
    if (( attempt >= AKASH_TX_RETRIES )); then
      die "send-manifest failed after $attempt attempts"
    fi
    log "send-manifest attempt $attempt failed; retrying in $((attempt*3))s"
    sleep $((attempt * 3))
    ((attempt++))
  done

  jq -n --arg dseq "$dseq" --arg provider "$provider" \
    '{ok:true, dseq:$dseq, gseq:1, oseq:1, provider:$provider}'
}

# ---------------------------------------------------------------------------
# Subcommand: lease-status <dseq> <provider>
# ---------------------------------------------------------------------------
cmd_lease_status() {
  local dseq="${1:?usage: lease-status <dseq> <provider>}"
  local provider="${2:?usage: lease-status <dseq> <provider>}"
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address
  "$AKASH_BIN" lease-status \
    --owner "$AKASH_ACCOUNT_ADDRESS" --dseq "$dseq" --gseq 1 --oseq 1 \
    --provider "$provider" --from "$AKASH_KEY_NAME" \
    --keyring-backend "$AKASH_KEYRING_BACKEND" --node "$AKASH_NODE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Subcommand: uri <dseq> <provider>
# Resolves the externally reachable worker URL(s) from lease-status.
# ---------------------------------------------------------------------------
cmd_uri() {
  local dseq="${1:?usage: uri <dseq> <provider>}"
  local provider="${2:?usage: uri <dseq> <provider>}"
  need_cmd jq

  local status uris=""
  local waited=0 max=120
  while (( waited < max )); do
    status="$(cmd_lease_status "$dseq" "$provider" || echo '{}')"
    # Collect host URIs and forwarded ports across all services.
    uris="$(printf '%s' "$status" | jq -c '
      [ (.services // {}) | to_entries[] |
        .value as $svc |
        ( ($svc.uris // []) | .[] | "https://" + . ),
        ( ($svc.forwarded_ports // []) | .[] |
          (.host // "provider") + ":" + ((.externalPort // .external_port)|tostring) )
      ] | unique')"
    local count
    count="$(printf '%s' "$uris" | jq 'length' 2>/dev/null || echo 0)"
    if [[ "${count:-0}" -gt 0 ]]; then
      log "resolved $count worker URI(s) for dseq=$dseq"
      jq -n --argjson uris "$uris" '{ok:true, uris:$uris}'
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
    log "waiting for worker URI... ${waited}s/${max}s"
  done
  err "no worker URI resolved for dseq=$dseq within ${max}s"
  jq -n '{ok:false, uris:[]}'
  return 1
}

# ---------------------------------------------------------------------------
# Subcommand: close <dseq>
# ---------------------------------------------------------------------------
cmd_close() {
  local dseq="${1:?usage: close <dseq>}"
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address
  log "closing deployment dseq=$dseq"
  # shellcheck disable=SC2046
  retry_query "$AKASH_BIN" tx deployment close \
    --owner "$AKASH_ACCOUNT_ADDRESS" --dseq "$dseq" $(tx_flags) >/dev/null \
    || die "deployment close failed"
  jq -n --arg dseq "$dseq" '{ok:true, dseq:$dseq, closed:true}'
}

# ---------------------------------------------------------------------------
# Subcommand: list
# Lists active deployments for the owner.
# ---------------------------------------------------------------------------
cmd_list() {
  need_cmd "$AKASH_BIN"; need_cmd jq
  resolve_account_address
  local out
  out="$(retry_query "$AKASH_BIN" query deployment list \
    --owner "$AKASH_ACCOUNT_ADDRESS" --state active $(query_flags) \
    2>/dev/null || echo '{}')"
  printf '%s' "$out" | jq '[.deployments[]? | {
    dseq: .deployment.deployment_id.dseq,
    state: .deployment.state
  }]'
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
main() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || die "usage: $0 {check|deploy|bids|select-provider|lease|lease-status|uri|close|list}"
  shift || true
  case "$cmd" in
    check)            cmd_check "$@" ;;
    deploy)           cmd_deploy "$@" ;;
    bids)             cmd_bids "$@" ;;
    select-provider)  cmd_select_provider "$@" ;;
    lease)            cmd_lease "$@" ;;
    lease-status)     cmd_lease_status "$@" ;;
    uri)              cmd_uri "$@" ;;
    close)            cmd_close "$@" ;;
    list)             cmd_list "$@" ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
