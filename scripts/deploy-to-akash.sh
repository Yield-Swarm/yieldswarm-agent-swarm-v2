#!/usr/bin/env bash
# =============================================================================
# deploy-to-akash.sh — Production Akash deployment (provider-services + JWT)
#
# Full lifecycle:
#   preflight → (optional Vault JWT) → create deployment → query bids →
#   select provider → create lease → send manifest (JWT auth) → health checks
#
# Usage:
#   ./scripts/deploy-to-akash.sh deploy [sdl-file]
#   ./scripts/deploy-to-akash.sh bids <dseq>
#   ./scripts/deploy-to-akash.sh lease <dseq> <provider> [sdl-file]
#   ./scripts/deploy-to-akash.sh manifest <dseq> <provider> [sdl-file]
#   ./scripts/deploy-to-akash.sh status <dseq> <provider>
#   ./scripts/deploy-to-akash.sh health <dseq> <provider>
#   ./scripts/deploy-to-akash.sh close <dseq>
#
# Docs: docs/AKASH_DEPLOY.md
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/vault-env.sh
source "${SCRIPT_DIR}/lib/vault-env.sh" 2>/dev/null || true
# shellcheck source=scripts/lib/vault-akash-bootstrap.sh
source "${SCRIPT_DIR}/lib/vault-akash-bootstrap.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Configuration (override via deploy/akash.env, deploy/config.env, or .env)
# ---------------------------------------------------------------------------
load_env_files() {
  local f
  for f in \
    "${REPO_ROOT}/deploy/akash.env" \
    "${REPO_ROOT}/deploy/config.env" \
    "${REPO_ROOT}/.env"
  do
    [[ -f "$f" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  done
}
load_env_files

# Akash CLI
AKASH_BIN="${AKASH_BIN:-provider-services}"

# Chain
AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-os}"
AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"
AKASH_ACCOUNT_ADDRESS="${AKASH_ACCOUNT_ADDRESS:-}"
AKASH_GAS="${AKASH_GAS:-auto}"
AKASH_GAS_ADJUSTMENT="${AKASH_GAS_ADJUSTMENT:-1.4}"
AKASH_GAS_PRICES="${AKASH_GAS_PRICES:-0.025uakt}"
AKASH_DEPOSIT="${AKASH_DEPOSIT:-5000000uakt}"

# Provider auth: jwt (default, recommended) or mtls (legacy on-chain cert)
AKASH_AUTH_MODE="${AKASH_AUTH_MODE:-jwt}"

# Bid selection
AKASH_BID_WAIT_SECONDS="${AKASH_BID_WAIT_SECONDS:-180}"
AKASH_BID_POLL_INTERVAL="${AKASH_BID_POLL_INTERVAL:-10}"
AKASH_MAX_BID_PRICE="${AKASH_MAX_BID_PRICE:-700000}"
# Preferred production provider (europlots.com); unset to auto-select cheapest bid
AKASH_PROVIDER="${AKASH_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"
AKASH_GPU_MODEL="${AKASH_GPU_MODEL:-rtx3090}"

# SDL + health
AKASH_SDL="${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}"
HEALTH_PATH="${HEALTH_PATH:-/healthz}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-300}"
HEALTH_POLL_INTERVAL="${HEALTH_POLL_INTERVAL:-10}"

# State output
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
STATE_FILE="${STATE_FILE:-${RUN_DIR}/akash-deploy.json}"

# Vault runtime injection (wrapped SecretID → Akash deployment --env)
VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-auto}"
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
VAULT_WRAP_TTL="${VAULT_WRAP_TTL:-600s}"

# Vault deploy-host config (optional — load Akash wallet/RPC before deploy)
VAULT_LOAD_AKASH="${VAULT_LOAD_AKASH:-false}"
VAULT_AKASH_SECRET_PATH="${VAULT_AKASH_SECRET_PATH:-yieldswarm/data/runtime/akash}"

# Retries
AKASH_TX_RETRIES="${AKASH_TX_RETRIES:-3}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()  { echo "[$(ts)] [deploy-to-akash] $*" >&2; }
die()  { echo "[$(ts)] [deploy-to-akash] ERROR: $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

json_tmp() { mktemp "${TMPDIR:-/tmp}/akash-deploy.XXXXXX.json"; }

ensure_run_dir() { mkdir -p "${RUN_DIR}"; }

# ---------------------------------------------------------------------------
# Optional: load Akash config from Vault via JWT / AppRole / token
# ---------------------------------------------------------------------------
vault_load_akash_config() {
  [[ "${VAULT_LOAD_AKASH}" == "true" ]] || return 0
  [[ -n "${VAULT_ADDR:-}" ]] || die "VAULT_LOAD_AKASH=true but VAULT_ADDR is unset"

  log "loading Akash config from Vault (${VAULT_AKASH_SECRET_PATH})"
  local token tmp
  token="$(vault_token)" || die "Vault authentication failed"
  tmp="$(mktemp)"
  chmod 600 "$tmp"

  vault__curl GET "${VAULT_AKASH_SECRET_PATH}" \
    -H "X-Vault-Token: ${token}" | vault__python -c '
import json, sys
p = json.load(sys.stdin).get("data", {}).get("data", {})
for k, v in sorted(p.items()):
    if v is not None:
        print(f"{k.upper()}={v}")
' > "$tmp" || die "failed to read Vault path ${VAULT_AKASH_SECRET_PATH}"

  set -a
  # shellcheck disable=SC1090
  source "$tmp"
  set +a
  rm -f "$tmp"
  log "Vault Akash config loaded"
}

# ---------------------------------------------------------------------------
# Account + CLI helpers
# ---------------------------------------------------------------------------
resolve_owner() {
  if [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]]; then
    return 0
  fi
  AKASH_ACCOUNT_ADDRESS="$("${AKASH_BIN}" keys show "${AKASH_KEY_NAME}" -a \
    --keyring-backend "${AKASH_KEYRING_BACKEND}" 2>/dev/null || true)"
  [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]] || \
    die "cannot resolve owner address; set AKASH_ACCOUNT_ADDRESS or import key ${AKASH_KEY_NAME}"
}

query_flags() {
  printf -- '--node %s --chain-id %s --output json' "${AKASH_NODE}" "${AKASH_CHAIN_ID}"
}

tx_flags() {
  printf -- '--node %s --chain-id %s --from %s --keyring-backend %s --gas %s --gas-adjustment %s --gas-prices %s --yes --output json' \
    "${AKASH_NODE}" "${AKASH_CHAIN_ID}" "${AKASH_KEY_NAME}" "${AKASH_KEYRING_BACKEND}" \
    "${AKASH_GAS}" "${AKASH_GAS_ADJUSTMENT}" "${AKASH_GAS_PRICES}"
}

manifest_flags() {
  # provider-services uses JWT by default (v0.10+) for provider API calls.
  # --auth-mode jwt is explicit; mtls requires on-chain cert publish.
  printf -- '--node %s --from %s --keyring-backend %s --auth-mode %s' \
    "${AKASH_NODE}" "${AKASH_KEY_NAME}" "${AKASH_KEYRING_BACKEND}" "${AKASH_AUTH_MODE}"
}

retry() {
  local attempt=1 max="${AKASH_TX_RETRIES}" delay=2
  local out rc
  while :; do
    if out="$("$@" 2>&1)"; then
      printf '%s' "$out"
      return 0
    fi
    rc=$?
    if (( attempt >= max )); then
      die "command failed after ${max} attempts: $* :: ${out}"
    fi
    log "attempt ${attempt}/${max} failed; retrying in ${delay}s"
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
cmd_preflight() {
  local sdl="${1:-${AKASH_SDL}}"
  if [[ -x "${SCRIPT_DIR}/akash-preflight.sh" ]]; then
    "${SCRIPT_DIR}/akash-preflight.sh" --json "${sdl}" || die "preflight NO-GO — run ./scripts/akash-preflight.sh for details"
    return 0
  fi

  need_cmd "${AKASH_BIN}"
  need_cmd jq
  need_cmd curl
  vault_load_akash_config
  resolve_owner

  [[ -f "${REPO_ROOT}/${sdl}" || -f "${sdl}" ]] || die "SDL not found: ${sdl}"

  local balance min_bal="${AKASH_MIN_BALANCE_UAKT:-500000}"
  balance="$(retry "${AKASH_BIN}" query bank balances "${AKASH_ACCOUNT_ADDRESS}" \
    $(query_flags) | jq -r '[.balances[]? | select(.denom=="uakt") | .amount][0] // "0"')"

  [[ "${balance}" -ge "${min_bal}" ]] || \
    die "insufficient balance: ${balance} uakt (need >= ${min_bal} uakt / 0.5 AKT)"

  log "preflight OK"
  jq -n \
    --arg bin "${AKASH_BIN}" \
    --arg owner "${AKASH_ACCOUNT_ADDRESS}" \
    --arg node "${AKASH_NODE}" \
    --arg chain "${AKASH_CHAIN_ID}" \
    --arg auth "${AKASH_AUTH_MODE}" \
    --arg sdl "${sdl}" \
    --arg balance "${balance}" \
    --arg provider "${AKASH_PROVIDER}" \
    '{
      ok: true,
      bin: $bin,
      owner: $owner,
      node: $node,
      chain_id: $chain,
      auth_mode: $auth,
      sdl: $sdl,
      balance_uakt: ($balance | tonumber),
      preferred_provider: $provider
    }'
}

# ---------------------------------------------------------------------------
# Optional mTLS cert (skipped when AKASH_AUTH_MODE=jwt)
# ---------------------------------------------------------------------------
ensure_auth() {
  if [[ "${AKASH_AUTH_MODE}" == "jwt" ]]; then
    log "using JWT authentication (provider-services default; no on-chain cert required)"
    return 0
  fi

  log "mTLS mode: ensuring client certificate is published on-chain"
  if "${AKASH_BIN}" tx cert generate client --from "${AKASH_KEY_NAME}" \
      --keyring-backend "${AKASH_KEYRING_BACKEND}" 2>/dev/null; then
    retry "${AKASH_BIN}" tx cert publish client \
      --from "${AKASH_KEY_NAME}" \
      --keyring-backend "${AKASH_KEYRING_BACKEND}" \
      $(tx_flags) >/dev/null || log "cert publish skipped (may already exist)"
  else
    log "client certificate already present"
  fi
}

# ---------------------------------------------------------------------------
# Step 1: Create deployment
# ---------------------------------------------------------------------------
cmd_create_deployment() {
  local sdl="${1:-${AKASH_SDL}}"
  [[ -f "${sdl}" ]] || [[ -f "${REPO_ROOT}/${sdl}" ]] || die "SDL not found: ${sdl}"
  [[ -f "${sdl}" ]] || sdl="${REPO_ROOT}/${sdl}"

  vault_load_akash_config
  resolve_owner
  ensure_auth

  local vault_env_args=()
  if vault_maybe_prepare_for_sdl "$sdl" "${VAULT_AKASH_ROLE}" 2>/dev/null; then
    while IFS= read -r flag; do
      [[ -n "$flag" ]] && vault_env_args+=("$flag")
    done < <(vault_akash_env_flags)
    vault_write_bootstrap_audit "${RUN_DIR}/vault-akash-bootstrap.json" 2>/dev/null || true
  fi

  log "creating deployment from ${sdl}"
  local out dseq
  out="$(retry "${AKASH_BIN}" tx deployment create "${sdl}" \
    --deposit "${AKASH_DEPOSIT}" \
    "${vault_env_args[@]}" \
    $(tx_flags))"

  dseq="$(printf '%s' "$out" | jq -r '
    ([.logs[]?.events[]? | .attributes[]? | select(.key=="dseq") | .value] | first)
    // (.height | tostring)
    // empty
  ')"

  [[ -n "${dseq}" && "${dseq}" != "null" ]] || \
    die "could not parse dseq from deployment tx"

  ensure_run_dir
  printf '%s' "$out" > "${RUN_DIR}/akash-create-tx.json"
  log "deployment created: dseq=${dseq}"
  jq -n --arg dseq "$dseq" --arg owner "$AKASH_ACCOUNT_ADDRESS" --arg sdl "$sdl" \
    '{ok:true, dseq:$dseq, owner:$owner, sdl:$sdl}'
}

# ---------------------------------------------------------------------------
# Step 2: Query bids
# ---------------------------------------------------------------------------
cmd_bids() {
  local dseq="${1:?usage: bids <dseq>}"
  resolve_owner

  local waited=0 out count
  while (( waited < AKASH_BID_WAIT_SECONDS )); do
    out="$(retry "${AKASH_BIN}" query market bid list \
      --owner "${AKASH_ACCOUNT_ADDRESS}" \
      --dseq "${dseq}" \
      --state open \
      --node "${AKASH_NODE}" \
      --output json)"

    count="$(printf '%s' "$out" | jq '[.bids[]?] | length')"
    if [[ "${count:-0}" -gt 0 ]]; then
      log "found ${count} open bid(s) for dseq=${dseq}"
      ensure_run_dir
      printf '%s' "$out" > "${RUN_DIR}/akash-bids-${dseq}.json"
      printf '%s' "$out" | jq '[.bids[]? | {
        provider: .bid.bid_id.provider,
        price: (.bid.price.amount | tonumber),
        denom: .bid.price.denom,
        state: .bid.state
      }]'
      return 0
    fi

    log "waiting for bids... ${waited}s / ${AKASH_BID_WAIT_SECONDS}s"
    sleep "${AKASH_BID_POLL_INTERVAL}"
    waited=$((waited + AKASH_BID_POLL_INTERVAL))
  done

  die "no bids received within ${AKASH_BID_WAIT_SECONDS}s for dseq=${dseq}"
}

# ---------------------------------------------------------------------------
# Step 3: Select provider (cheapest under max price, or AKASH_PROVIDER override)
# ---------------------------------------------------------------------------
cmd_select_provider() {
  local dseq="${1:?usage: select-provider <dseq>}"
  if [[ -n "${AKASH_PROVIDER}" ]]; then
    log "using AKASH_PROVIDER override: ${AKASH_PROVIDER}"
    jq -n --arg p "${AKASH_PROVIDER}" '{provider:$p, price:null, source:"override"}'
    return 0
  fi

  local bids_json provider price
  bids_json="$(cmd_bids "${dseq}")"
  provider="$(printf '%s' "$bids_json" | jq -r --argjson max "${AKASH_MAX_BID_PRICE}" \
    '[.[] | select(.price <= $max)] | sort_by(.price) | .[0].provider // empty')"
  price="$(printf '%s' "$bids_json" | jq -r --argjson max "${AKASH_MAX_BID_PRICE}" \
    '[.[] | select(.price <= $max)] | sort_by(.price) | .[0].price // empty')"

  [[ -n "${provider}" && "${provider}" != "null" ]] || \
    die "no acceptable bid under max price ${AKASH_MAX_BID_PRICE} uakt/block (gpu=${AKASH_GPU_MODEL})"

  log "selected provider=${provider} @ ${price} uakt/block"
  jq -n --arg p "$provider" --argjson price "${price}" \
    '{provider:$p, price:$price, source:"auto"}'
}

# ---------------------------------------------------------------------------
# Step 4: Create lease
# ---------------------------------------------------------------------------
cmd_create_lease() {
  local dseq="${1:?usage: lease <dseq> <provider> [sdl]}"
  local provider="${2:?usage: lease <dseq> <provider> [sdl]}"
  local sdl="${3:-${AKASH_SDL}}"
  [[ -f "${sdl}" ]] || sdl="${REPO_ROOT}/${sdl}"

  resolve_owner
  ensure_auth

  log "creating lease dseq=${dseq} provider=${provider}"
  retry "${AKASH_BIN}" tx market lease create \
    --owner "${AKASH_ACCOUNT_ADDRESS}" \
    --dseq "${dseq}" \
    --gseq 1 \
    --oseq 1 \
    --provider "${provider}" \
    $(tx_flags) >/dev/null

  log "lease created; sending manifest (auth=${AKASH_AUTH_MODE})"
  cmd_send_manifest "${dseq}" "${provider}" "${sdl}"
}

# ---------------------------------------------------------------------------
# Step 5: Send manifest (JWT-authenticated provider API)
# ---------------------------------------------------------------------------
cmd_send_manifest() {
  local dseq="${1:?usage: manifest <dseq> <provider> [sdl]}"
  local provider="${2:?usage: manifest <dseq> <provider> [sdl]}"
  local sdl="${3:-${AKASH_SDL}}"
  [[ -f "${sdl}" ]] || sdl="${REPO_ROOT}/${sdl}"

  resolve_owner
  log "send-manifest dseq=${dseq} provider=${provider} auth=${AKASH_AUTH_MODE}"

  retry "${AKASH_BIN}" send-manifest "${sdl}" \
    --owner "${AKASH_ACCOUNT_ADDRESS}" \
    --dseq "${dseq}" \
    --provider "${provider}" \
    $(manifest_flags) >/dev/null

  log "manifest accepted by provider"
  jq -n --arg dseq "$dseq" --arg provider "$provider" --arg auth "${AKASH_AUTH_MODE}" \
    '{ok:true, dseq:$dseq, provider:$provider, auth_mode:$auth}'
}

# ---------------------------------------------------------------------------
# Step 6: Lease status + URI resolution
# ---------------------------------------------------------------------------
cmd_status() {
  local dseq="${1:?usage: status <dseq> <provider>}"
  local provider="${2:?usage: status <dseq> <provider>}"
  resolve_owner

  "${AKASH_BIN}" lease-status \
    --owner "${AKASH_ACCOUNT_ADDRESS}" \
    --dseq "${dseq}" \
    --gseq 1 \
    --oseq 1 \
    --provider "${provider}" \
    $(manifest_flags) 2>/dev/null || echo '{}'
}

resolve_uris() {
  local dseq="$1" provider="$2"
  local status uris_json
  status="$(cmd_status "${dseq}" "${provider}")"

  uris_json="$(printf '%s' "$status" | jq -c '
    [ (.services // {}) | to_entries[] |
      .value as $svc |
      ( ($svc.uris // []) | .[] ),
      ( ($svc.uris // []) | .[] | if test("^https?://") then . else "https://" + . end )
    ] | unique | map(select(length > 0))
  ' 2>/dev/null || echo '[]')"

  # Fallback: scrape http(s) URLs from raw lease-status text output
  if [[ "$(printf '%s' "$uris_json" | jq 'length')" -eq 0 ]]; then
    uris_json="$(printf '%s' "$status" | grep -oE 'https?://[a-zA-Z0-9._/-]+' | jq -R . | jq -s 'unique')"
  fi

  printf '%s' "$uris_json"
}

# ---------------------------------------------------------------------------
# Step 7: Health checks (HTTP GET /healthz on resolved URIs)
# ---------------------------------------------------------------------------
cmd_health() {
  local dseq="${1:?usage: health <dseq> <provider>}"
  local provider="${2:?usage: health <dseq> <provider>}"

  local uris_json waited=0 uri base url code
  uris_json='[]'

  log "waiting up to ${HEALTH_TIMEOUT_SECONDS}s for worker URIs + ${HEALTH_PATH}"

  while (( waited < HEALTH_TIMEOUT_SECONDS )); do
    uris_json="$(resolve_uris "${dseq}" "${provider}")"
    if [[ "$(printf '%s' "$uris_json" | jq 'length')" -gt 0 ]]; then
      break
    fi
    sleep "${HEALTH_POLL_INTERVAL}"
    waited=$((waited + HEALTH_POLL_INTERVAL))
    log "no URIs yet... ${waited}s"
  done

  [[ "$(printf '%s' "$uris_json" | jq 'length')" -gt 0 ]] || \
    die "no service URIs resolved within ${HEALTH_TIMEOUT_SECONDS}s"

  local results='[]' healthy=0 total=0
  while IFS= read -r uri; do
    [[ -n "$uri" && "$uri" != "null" ]] || continue
    total=$((total + 1))
    base="${uri%/}"
    url="${base}${HEALTH_PATH}"
    code="$(curl -sf -o /dev/null -w '%{http_code}' --max-time 15 "${url}" 2>/dev/null || echo "000")"
    if [[ "${code}" =~ ^2 ]]; then
      healthy=$((healthy + 1))
      log "health OK ${url} (${code})"
    else
      log "health FAIL ${url} (${code})"
    fi
    results="$(printf '%s' "$results" | jq --arg u "$url" --arg c "$code" \
      '. + [{url:$u, status_code:($c|tonumber)}]')"
  done < <(printf '%s' "$uris_json" | jq -r '.[]')

  local ok=false
  [[ "${healthy}" -gt 0 ]] && ok=true

  jq -n \
    --argjson uris "$uris_json" \
    --argjson checks "$results" \
    --argjson healthy "$healthy" \
    --argjson total "$total" \
    --arg path "$HEALTH_PATH" \
    '{ok:($healthy > 0), uris:$uris, health_path:$path, healthy:$healthy, total:$total, checks:$checks}'
}

# ---------------------------------------------------------------------------
# Full deploy pipeline
# ---------------------------------------------------------------------------
write_state() {
  local dseq="$1" provider="$2" price="$3" sdl="$4" health_json="$5"
  local uris_json
  uris_json="$(printf '%s' "$health_json" | jq '.uris')"

  ensure_run_dir
  jq -n \
    --arg deployed_at "$(ts)" \
    --arg owner "${AKASH_ACCOUNT_ADDRESS}" \
    --arg dseq "$dseq" \
    --arg provider "$provider" \
    --argjson price "${price:-null}" \
    --arg sdl "$sdl" \
    --arg auth "${AKASH_AUTH_MODE}" \
    --argjson uris "$uris_json" \
    --argjson health "$health_json" \
    '{
      deployed_at: $deployed_at,
      owner: $owner,
      dseq: $dseq,
      gseq: 1,
      oseq: 1,
      provider: $provider,
      price_uakt_per_block: $price,
      sdl: $sdl,
      auth_mode: $auth,
      uris: $uris,
      health: $health
    }' > "${STATE_FILE}"

  # Shell-friendly env snippet for downstream scripts
  {
    echo "# Generated by deploy-to-akash.sh on $(ts)"
    echo "AKASH_OWNER=${AKASH_ACCOUNT_ADDRESS}"
    echo "AKASH_DSEQ=${dseq}"
    echo "AKASH_PROVIDER=${provider}"
    echo "AKASH_AUTH_MODE=${AKASH_AUTH_MODE}"
    echo "AKASH_WORKER_URLS=$(printf '%s' "$uris_json" | jq -r 'join(",")')"
  } > "${RUN_DIR}/akash-lease.env"

  log "state written to ${STATE_FILE}"
}

cmd_deploy() {
  local sdl="${1:-${AKASH_SDL}}"
  [[ -f "${sdl}" ]] || sdl="${REPO_ROOT}/${sdl}"

  log "deploy pipeline start sdl=${sdl} provider=${AKASH_PROVIDER:-auto}"
  cmd_preflight "${sdl}" >/dev/null || die "preflight failed"

  local create_json dseq select_json provider price
  create_json="$(cmd_create_deployment "${sdl}")"
  dseq="$(printf '%s' "$create_json" | jq -r '.dseq')"

  select_json="$(cmd_select_provider "${dseq}")"
  provider="$(printf '%s' "$select_json" | jq -r '.provider')"
  price="$(printf '%s' "$select_json" | jq -r '.price // empty')"

  cmd_create_lease "${dseq}" "${provider}" "${sdl}" >/dev/null

  log "waiting 15s for provider to start containers"
  sleep 15

  local health_json
  health_json="$(cmd_health "${dseq}" "${provider}")"
  printf '%s' "$health_json" | jq -e '.ok' >/dev/null || \
    die "health checks failed — lease is live but worker not healthy yet"

  write_state "${dseq}" "${provider}" "${price:-null}" "${sdl}" "${health_json}"

  if [[ -x "${SCRIPT_DIR}/verify-akash-lease.sh" ]]; then
    log "running post-deploy verification"
    "${SCRIPT_DIR}/verify-akash-lease.sh" || log "WARN: verify-akash-lease reported failures (lease may still be warming up)"
  fi

  jq -n \
    --arg dseq "$dseq" \
    --arg provider "$provider" \
    --arg state "${STATE_FILE}" \
    --argjson health "$health_json" \
    '{
      ok: true,
      message: "Akash deployment complete",
      dseq: $dseq,
      provider: $provider,
      state_file: $state,
      uris: $health.uris,
      health: $health
    }'
}

# ---------------------------------------------------------------------------
# Close deployment
# ---------------------------------------------------------------------------
cmd_close() {
  local dseq="${1:?usage: close <dseq>}"
  resolve_owner
  log "closing deployment dseq=${dseq}"
  retry "${AKASH_BIN}" tx deployment close \
    --owner "${AKASH_ACCOUNT_ADDRESS}" \
    --dseq "${dseq}" \
    $(tx_flags) >/dev/null
  jq -n --arg dseq "$dseq" '{ok:true, closed:true, dseq:$dseq}'
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
deploy-to-akash.sh — Production Akash deployment (provider-services + JWT)

Commands:
  deploy [sdl]                 Full pipeline: create → bids → lease → manifest → health
  preflight [sdl]              Verify CLI, balance, SDL
  create [sdl]                 Create on-chain deployment only
  bids <dseq>                  Query and wait for open bids (JSON)
  select-provider <dseq>       Pick cheapest bid under AKASH_MAX_BID_PRICE
  lease <dseq> <provider> [sdl]  Create lease + send manifest
  manifest <dseq> <provider> [sdl] Send manifest only
  status <dseq> <provider>     lease-status output
  health <dseq> <provider>     HTTP health checks on worker URIs
  close <dseq>                 Close deployment

Environment (see deploy/akash.env.example):
  AKASH_KEY_NAME               Wallet key name (required)
  AKASH_AUTH_MODE              jwt (default) or mtls
  AKASH_SDL                    SDL file (default: deploy/deploy-swarm-monolith.yaml)
  AKASH_MAX_BID_PRICE          Max uakt/block (default: 700000)
  VAULT_LOAD_AKASH             Load config from Vault before deploy (true/false)

Docs: docs/AKASH_DEPLOY.md
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local cmd="${1:-deploy}"
  shift || true

  case "${cmd}" in
    -h|--help|help) usage; exit 0 ;;
    preflight)      cmd_preflight "$@" ;;
    create)         cmd_create_deployment "$@" ;;
    bids)           cmd_bids "$@" ;;
    select-provider) cmd_select_provider "$@" ;;
    lease)          cmd_create_lease "$@" ;;
    manifest)       cmd_send_manifest "$@" ;;
    status)         cmd_status "$@" ;;
    health)         cmd_health "$@" ;;
    close)          cmd_close "$@" ;;
    deploy)         cmd_deploy "$@" ;;
    *) die "unknown command: ${cmd}. Run with --help." ;;
  esac
}

main "$@"
