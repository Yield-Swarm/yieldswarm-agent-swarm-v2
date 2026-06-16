#!/usr/bin/env bash
# =============================================================================
# akash-preflight.sh — GO/NO-GO gate before live Akash mainnet deploy
#
# Usage:
#   ./scripts/akash-preflight.sh [sdl-file]
#   ./scripts/akash-preflight.sh --json [sdl-file]
#
# Exit 0 = GO, exit 1 = NO-GO (with fix commands printed)
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/vault-env.sh
source "${SCRIPT_DIR}/lib/vault-env.sh" 2>/dev/null || true
# shellcheck source=scripts/lib/vault-akash-bootstrap.sh
source "${SCRIPT_DIR}/lib/vault-akash-bootstrap.sh" 2>/dev/null || true

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && { JSON_MODE=1; shift; }

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

AKASH_BIN="${AKASH_BIN:-provider-services}"
AKASH_NODE="${AKASH_NODE:-https://rpc.akashnet.net:443}"
AKASH_CHAIN_ID="${AKASH_CHAIN_ID:-akashnet-2}"
AKASH_KEYRING_BACKEND="${AKASH_KEYRING_BACKEND:-os}"
AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"
AKASH_ACCOUNT_ADDRESS="${AKASH_ACCOUNT_ADDRESS:-}"
AKASH_AUTH_MODE="${AKASH_AUTH_MODE:-jwt}"
AKASH_SDL="${1:-${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}}"
AKASH_SDL_SECONDARY="${AKASH_SDL_SECONDARY:-deploy/akash-bittensor-miner.sdl.yml}"
MIN_BALANCE_UAKT="${AKASH_MIN_BALANCE_UAKT:-500000}"
EUROPLOTS_PROVIDER="${AKASH_PROVIDER:-akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc}"
VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-auto}"

declare -a CHECKS=()
declare -a FIXES=()
GO=true

add_check() {
  local id="$1" status="$2" detail="$3" fix="${4:-}"
  CHECKS+=("$(jq -nc --arg id "$id" --arg status "$status" --arg detail "$detail" --arg fix "$fix" \
    '{id:$id, status:$status, detail:$detail, fix:$fix}')")
  if [[ "$status" != "pass" ]]; then
    GO=false
    [[ -n "$fix" ]] && FIXES+=("$fix")
  fi
}

resolve_sdl() {
  local sdl="$1"
  if [[ -f "${sdl}" ]]; then
    printf '%s' "${sdl}"
  elif [[ -f "${REPO_ROOT}/${sdl}" ]]; then
    printf '%s' "${REPO_ROOT}/${sdl}"
  else
    printf ''
  fi
}

resolve_owner() {
  if [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]]; then
    return 0
  fi
  AKASH_ACCOUNT_ADDRESS="$("${AKASH_BIN}" keys show "${AKASH_KEY_NAME}" -a \
    --keyring-backend "${AKASH_KEYRING_BACKEND}" 2>/dev/null || true)"
}

# ---- Checks ----------------------------------------------------------------

if command -v "${AKASH_BIN}" >/dev/null 2>&1; then
  ver="$("${AKASH_BIN}" version 2>/dev/null | head -1 || echo unknown)"
  add_check "provider-services" "pass" "installed (${ver})"
else
  add_check "provider-services" "fail" "not found (${AKASH_BIN})" \
    "curl -sSfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash"
fi

for cmd in jq curl vault; do
  if command -v "$cmd" >/dev/null 2>&1; then
    add_check "tool-${cmd}" "pass" "${cmd} available"
  else
    add_check "tool-${cmd}" "fail" "${cmd} missing" "sudo apt-get install -y ${cmd}  # or brew install ${cmd}"
  fi
done

resolve_owner
if [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]]; then
  add_check "wallet-keyring" "pass" "key '${AKASH_KEY_NAME}' -> ${AKASH_ACCOUNT_ADDRESS}"
else
  add_check "wallet-keyring" "fail" "key '${AKASH_KEY_NAME}' not in keyring (${AKASH_KEYRING_BACKEND})" \
    "provider-services keys add ${AKASH_KEY_NAME} --keyring-backend ${AKASH_KEYRING_BACKEND}"
fi

if [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]] && command -v "${AKASH_BIN}" >/dev/null 2>&1; then
  bal="$("${AKASH_BIN}" query bank balances "${AKASH_ACCOUNT_ADDRESS}" \
    --node "${AKASH_NODE}" -o json 2>/dev/null \
    | jq -r '[.balances[]? | select(.denom=="uakt") | .amount][0] // "0"')"
  akt_human="$(awk "BEGIN {printf \"%.4f\", ${bal}/1000000}")"
  if [[ "${bal}" -ge "${MIN_BALANCE_UAKT}" ]]; then
    add_check "wallet-balance" "pass" "${akt_human} AKT (${bal} uakt) >= ${MIN_BALANCE_UAKT} uakt minimum"
  else
    add_check "wallet-balance" "fail" "${akt_human} AKT (${bal} uakt) — need >= 0.5 AKT (${MIN_BALANCE_UAKT} uakt)" \
      "Fund wallet: provider-services tx bank send ${AKASH_ACCOUNT_ADDRESS} <amount>uakt --from <funder> --node ${AKASH_NODE} --chain-id ${AKASH_CHAIN_ID} --yes"
  fi
fi

if command -v "${AKASH_BIN}" >/dev/null 2>&1; then
  if "${AKASH_BIN}" status --node "${AKASH_NODE}" >/dev/null 2>&1; then
    add_check "rpc-node" "pass" "RPC reachable (${AKASH_NODE})"
  else
    add_check "rpc-node" "fail" "RPC unreachable (${AKASH_NODE})" \
      "export AKASH_NODE=https://rpc.akashnet.net:443"
  fi
fi

case "${AKASH_AUTH_MODE}" in
  jwt)
    if [[ -n "${AKASH_ACCOUNT_ADDRESS}" ]]; then
      add_check "auth-jwt" "pass" "JWT mode — wallet key signs provider API tokens (no on-chain cert)"
    else
      add_check "auth-jwt" "warn" "JWT mode selected but wallet not ready"
    fi
    ;;
  mtls)
    add_check "auth-mtls" "warn" "mTLS mode — requires tx cert generate + publish before manifest"
    ;;
  *)
    add_check "auth-mode" "fail" "unknown AKASH_AUTH_MODE=${AKASH_AUTH_MODE}" \
      "export AKASH_AUTH_MODE=jwt"
    ;;
esac

sdl_primary="$(resolve_sdl "${AKASH_SDL}")"
if [[ -n "${sdl_primary}" ]]; then
  add_check "sdl-primary" "pass" "found ${sdl_primary}"
  if grep -qE 'VAULT_(SECRET_ID|TOKEN)=' "${sdl_primary}" 2>/dev/null; then
    add_check "sdl-primary-secrets" "fail" "plaintext secret values in ${AKASH_SDL}" \
      "Use key-only env entries (VAULT_WRAPPED_SECRET_ID) — values injected at deployment create"
  else
    add_check "sdl-primary-secrets" "pass" "no plaintext Vault secrets in SDL"
  fi
  if vault_sdl_needs_runtime_secrets "${sdl_primary}" 2>/dev/null; then
    add_check "sdl-primary-vault" "pass" "SDL expects Vault runtime bootstrap (--env injection)"
  fi
else
  add_check "sdl-primary" "fail" "SDL not found: ${AKASH_SDL}" \
    "ls deploy/deploy-swarm-monolith.yaml"
fi

sdl_secondary="$(resolve_sdl "${AKASH_SDL_SECONDARY}")"
if [[ -n "${sdl_secondary}" ]]; then
  add_check "sdl-bittensor" "pass" "found ${sdl_secondary}"
else
  add_check "sdl-bittensor" "warn" "optional SDL missing: ${AKASH_SDL_SECONDARY}"
fi

# Required env vars
missing_env=()
[[ -n "${VAULT_ADDR:-}" ]] || missing_env+=("VAULT_ADDR")
[[ -n "${AGENT_SHARD_ID:-}" ]] || AGENT_SHARD_ID=0

if [[ "${VAULT_INJECT_RUNTIME_SECRETS}" != "no" && "${VAULT_INJECT_RUNTIME_SECRETS}" != "false" ]]; then
  if [[ -n "${VAULT_ADDR:-}" ]]; then
    add_check "env-vault-addr" "pass" "VAULT_ADDR=${VAULT_ADDR}"
  else
    add_check "env-vault-addr" "fail" "VAULT_ADDR unset" \
      "export VAULT_ADDR=https://vault.yieldswarm.io:8200"
  fi

  token="${VAULT_TOKEN:-}"
  [[ -z "$token" && -n "${VAULT_TOKEN_FILE:-}" && -r "${VAULT_TOKEN_FILE}" ]] && token="$(<"${VAULT_TOKEN_FILE}")"
  [[ -z "$token" && -f "${REPO_ROOT}/.vault-token" ]] && token="$(<"${REPO_ROOT}/.vault-token")"

  if [[ -n "${VAULT_WRAPPED_SECRET_ID:-}" && -n "${VAULT_ROLE_ID:-}" ]]; then
    add_check "vault-bootstrap" "pass" "pre-exported VAULT_ROLE_ID + VAULT_WRAPPED_SECRET_ID"
  elif [[ -n "${token}" ]]; then
    if vault read -field=role_id "auth/approle/role/${VAULT_AKASH_ROLE}/role-id" >/dev/null 2>&1; then
      add_check "vault-bootstrap" "pass" "VAULT_TOKEN can read AppRole ${VAULT_AKASH_ROLE} (wrap will be minted at deploy)"
    else
      add_check "vault-bootstrap" "fail" "VAULT_TOKEN cannot read role ${VAULT_AKASH_ROLE}" \
        "./vault/setup/bootstrap.sh && export VAULT_TOKEN=<admin-token>"
    fi
  else
    add_check "vault-bootstrap" "fail" "no VAULT_TOKEN and no pre-exported wrap credentials" \
      "export VAULT_TOKEN=<token>  # or: vault login; scripts will mint wrapped SecretID at deploy"
  fi
else
  add_check "vault-bootstrap" "warn" "VAULT_INJECT_RUNTIME_SECRETS=${VAULT_INJECT_RUNTIME_SECRETS} — runtime secrets disabled"
fi

add_check "env-agent-shard" "pass" "AGENT_SHARD_ID=${AGENT_SHARD_ID}"
add_check "provider-target" "pass" "preferred provider: ${EUROPLOTS_PROVIDER} (provider.europlots.com)"

# ---- Report ----------------------------------------------------------------

if [[ "${JSON_MODE}" -eq 1 ]]; then
  checks_json="$(printf '%s\n' "${CHECKS[@]}" | jq -s '.')"
  fixes_json="$(printf '%s\n' "${FIXES[@]:-}" | jq -R -s 'split("\n") | map(select(length>0))')"
  go_json=false
  [[ "${GO}" == true ]] && go_json=true
  jq -n \
    --argjson go "${go_json}" \
    --arg owner "${AKASH_ACCOUNT_ADDRESS:-}" \
    --arg provider "${EUROPLOTS_PROVIDER}" \
    --arg sdl "${AKASH_SDL}" \
    --argjson checks "$checks_json" \
    --argjson fixes "$fixes_json" \
    '{go:$go, owner:$owner, preferred_provider:$provider, sdl:$sdl, checks:$checks, fixes:$fixes}'
  [[ "${GO}" == true ]] && exit 0 || exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           YieldSwarm Akash Preflight — GO/NO-GO             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

for entry in "${CHECKS[@]}"; do
  id="$(printf '%s' "$entry" | jq -r '.id')"
  status="$(printf '%s' "$entry" | jq -r '.status')"
  detail="$(printf '%s' "$entry" | jq -r '.detail')"
  case "$status" in
    pass) icon="✓" ;;
    warn) icon="!" ;;
    *)  icon="✗" ;;
  esac
  printf "  [%s] %-22s %s\n" "$icon" "$id" "$detail"
done

echo ""
if [[ "${GO}" == true ]]; then
  echo "RESULT: GO — ready for live deploy"
  echo ""
  echo "Next (europlots, Vault-injected monolith):"
  echo "  export VAULT_ADDR=${VAULT_ADDR}"
  echo "  export VAULT_TOKEN=<your-token>"
  echo "  export AGENT_SHARD_ID=0"
  echo "  export AKASH_PROVIDER=${EUROPLOTS_PROVIDER}"
  echo "  ./scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml"
  echo ""
  echo "Verify after deploy:"
  echo "  ./scripts/verify-akash-lease.sh"
  exit 0
fi

echo "RESULT: NO-GO — fix the items below before deploying"
echo ""
echo "── Fix commands ──"
if ((${#FIXES[@]} > 0)); then
  for fix in "${FIXES[@]}"; do
    echo "  $fix"
  done
else
  echo "  Review failed checks above"
fi
echo ""
exit 1
