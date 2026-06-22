#!/usr/bin/env bash
# vault/scripts/validate-secrets.sh
#
# Verify that required KV paths exist and contain non-empty keys before
# Terraform plan/apply or Akash live deploy.
#
# Usage:
#   export VAULT_ADDR=... VAULT_TOKEN=...
#   ./vault/scripts/validate-secrets.sh              # full stack (default)
#   ./vault/scripts/validate-secrets.sh --profile terraform
#   ./vault/scripts/validate-secrets.sh --profile akash
#   ./vault/scripts/validate-secrets.sh --json
#
# Exit 0 = all required checks pass, 1 = one or more failures.
set -Eeuo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set (admin or read-capable token)}"

KV_MOUNT="${KV_MOUNT:-yieldswarm}"
PROFILE="${VALIDATE_SECRETS_PROFILE:-full}"
JSON_MODE=0

usage() {
  cat <<'EOF'
Usage: validate-secrets.sh [--profile terraform|akash|full] [--json]

Profiles:
  terraform  cloud/* + rpc/* paths consumed by terraform/
  akash      runtime/* + akash/* paths consumed by Akash workloads
  full       terraform + akash (default)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:?--profile requires a value}"
      shift 2
      ;;
    --json) JSON_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required binary: $1" >&2
    exit 1
  }
}
require vault
require jq

log() { printf '[validate] %s\n' "$*" >&2; }

declare -a CHECKS=()
PASS=true

add_check() {
  local id="$1" status="$2" detail="$3"
  CHECKS+=("$(jq -nc --arg id "$id" --arg status "$status" --arg detail "$detail" \
    '{id:$id, status:$status, detail:$detail}')")
  [[ "$status" == "fail" ]] && PASS=false
}

# Return 0 when path exists (any version).
kv_exists() {
  local path="$1"
  vault kv get -format=json "${KV_MOUNT}/${path}" >/dev/null 2>&1
}

# Read a key from KV; prints empty string when missing.
kv_get() {
  local path="$1" key="$2"
  vault kv get -format=json "${KV_MOUNT}/${path}" 2>/dev/null \
    | jq -r --arg k "$key" '.data.data[$k] // empty' 2>/dev/null || true
}

# Require every listed key to be non-empty.
require_all_keys() {
  local path="$1"; shift
  local -a keys=("$@")
  local k val missing=()

  if ! kv_exists "$path"; then
    add_check "kv:${path}" "fail" "path missing"
    return 1
  fi

  for k in "${keys[@]}"; do
    val="$(kv_get "$path" "$k")"
    if [[ -z "$val" || "$val" == "null" || "$val" == "CHANGEME" || "$val" == "changeme" ]]; then
      missing+=("$k")
    fi
  done

  if ((${#missing[@]} == 0)); then
    add_check "kv:${path}" "pass" "present (${#keys[@]} keys)"
    return 0
  fi

  add_check "kv:${path}" "fail" "missing keys: ${missing[*]}"
  return 1
}

# Accept first matching path from a list (cloud vs providers alias).
require_all_keys_any() {
  local -a paths=()
  local p
  while [[ $# -gt 0 && "$1" != -- ]]; do
    paths+=("$1")
    shift
  done
  [[ "$1" == -- ]] && shift
  local -a keys=("$@")

  for p in "${paths[@]}"; do
    if kv_exists "$p"; then
      require_all_keys "$p" "${keys[@]}"
      return $?
    fi
  done

  local joined
  joined="$(IFS=' | '; echo "${paths[*]}")"
  add_check "kv:${joined}" "fail" "none of the alias paths exist"
  return 1
}

# Require at least one of the listed keys (wallet aliases).
require_any_key() {
  local path="$1"; shift
  local -a keys=("$@")
  local k val

  if ! kv_exists "$path"; then
    return 1
  fi

  for k in "${keys[@]}"; do
    val="$(kv_get "$path" "$k")"
    if [[ -n "$val" && "$val" != "null" && "$val" != "CHANGEME" && "$val" != "changeme" ]]; then
      add_check "kv:${path}" "pass" "wallet secret present (${k})"
      return 0
    fi
  done

  add_check "kv:${path}" "fail" "path exists but wallet keys empty"
  return 1
}

# Akash wallet: accept flat yieldswarm/akash, runtime/akash, or akash/wallet.
validate_akash_wallet() {
  local -a wallet_paths=(akash runtime/akash akash/wallet)
  local p
  for p in "${wallet_paths[@]}"; do
    if require_any_key "$p" key_name account_address owner_address wallet_mnemonic mnemonic; then
      return 0
    fi
  done
  add_check "kv:akash-wallet" "fail" \
    "missing — write yieldswarm/akash, runtime/akash, or akash/wallet (see SECRETS.md Appendix B)"
  return 1
}

validate_terraform_paths() {
  log "profile=terraform"
  require_all_keys_any cloud/azure providers/azure -- client_id client_secret tenant_id subscription_id
  require_all_keys_any cloud/runpod providers/runpod -- api_key
  require_all_keys_any cloud/vultr providers/vultr -- api_key
  require_all_keys_any cloud/digitalocean providers/digitalocean -- token

  # RPC bundle — solana URL or helius key
  if kv_exists rpc/solana; then
    val="$(kv_get rpc/solana http_url)"
    [[ -z "$val" ]] && val="$(kv_get rpc/solana url)"
    if [[ -n "$val" ]]; then
      add_check "kv:rpc/solana" "pass" "RPC URL present"
    else
      add_check "kv:rpc/solana" "fail" "need http_url or url"
    fi
  elif kv_exists rpc/helius; then
    require_all_keys rpc/helius api_key
  else
    add_check "kv:rpc/solana|helius" "fail" "need rpc/solana or rpc/helius"
  fi

  for p in rpc/birdeye rpc/jupiter rpc/raydium rpc/ton; do
    if kv_exists "$p"; then
      require_all_keys "$p" api_key
    else
      add_check "kv:${p}" "warn" "optional path missing (terraform may still plan)"
    fi
  done
}

validate_akash_paths() {
  log "profile=akash"
  validate_akash_wallet

  for p in runtime/core runtime/wallets runtime/llm runtime/backend runtime/bittensor; do
    if kv_exists "$p"; then
      add_check "kv:${p}" "pass" "present"
    else
      add_check "kv:${p}" "warn" "missing — seed via ./vault/scripts/seed-secrets.sh"
    fi
  done

  if kv_exists integrations/alchemy; then
    require_all_keys integrations/alchemy api_key
  else
    add_check "kv:integrations/alchemy" "warn" "optional — Alchemy RPC mesh not seeded"
  fi

  if kv_exists agents/shards/0; then
    add_check "kv:agents/shards/0" "pass" "shard 0 present"
  else
    add_check "kv:agents/shards/0" "warn" "shard 0 missing (AGENT_SHARD_ID=0 deploy)"
  fi
}

validate_bootstrap() {
  if vault secrets list -format=json | jq -e --arg m "${KV_MOUNT}/" '.[$m]' >/dev/null 2>&1; then
    add_check "mount:kv" "pass" "KV v2 mount ${KV_MOUNT}/ enabled"
  else
    add_check "mount:kv" "fail" "KV mount ${KV_MOUNT}/ missing — run ./infra/vault/scripts/bootstrap.sh"
  fi

  if vault auth list -format=json | jq -e '."approle/"' >/dev/null 2>&1; then
    add_check "auth:approle" "pass" "AppRole enabled"
  else
    add_check "auth:approle" "fail" "AppRole not enabled"
  fi

  for role in terraform akash-runtime; do
    if vault read -format=json "auth/approle/role/${role}/role-id" >/dev/null 2>&1; then
      add_check "approle:${role}" "pass" "role configured"
    else
      add_check "approle:${role}" "fail" "role ${role} missing — run bootstrap"
    fi
  done
}

# ---- Run -------------------------------------------------------------------

if vault status -format=json >/dev/null 2>&1; then
  sealed="$(vault status -format=json | jq -r '.sealed')"
  if [[ "$sealed" == "true" ]]; then
    add_check "vault:status" "fail" "cluster sealed"
  else
    add_check "vault:status" "pass" "reachable at ${VAULT_ADDR}"
  fi
else
  add_check "vault:status" "fail" "cannot reach ${VAULT_ADDR}"
fi

validate_bootstrap

case "$PROFILE" in
  terraform) validate_terraform_paths ;;
  akash) validate_akash_paths ;;
  full)
    validate_terraform_paths
    validate_akash_paths
    ;;
  *)
    echo "unknown profile: ${PROFILE} (use terraform|akash|full)" >&2
    exit 2
    ;;
esac

if [[ "$JSON_MODE" -eq 1 ]]; then
  checks_json="$(printf '%s\n' "${CHECKS[@]}" | jq -s '.')"
  go_json=false
  [[ "$PASS" == true ]] && go_json=true
  jq -n \
    --arg profile "$PROFILE" \
    --argjson pass "${go_json}" \
    --argjson checks "$checks_json" \
    '{profile:$profile, pass:$pass, checks:$checks}'
  [[ "$PASS" == true ]] && exit 0 || exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         YieldSwarm Vault Secret Validation                   ║"
echo "║         profile: ${PROFILE}$(printf '%*s' $((33 - ${#PROFILE})) '')║"
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
  printf "  [%s] %-28s %s\n" "$icon" "$id" "$detail"
done

echo ""
if [[ "$PASS" == true ]]; then
  echo "RESULT: PASS — secrets ready for ${PROFILE} deploy"
  echo ""
  echo "Next:"
  echo "  make akash-preflight && make deploy-akash-europlots   # Akash"
  echo "  cd terraform && terraform init && terraform plan      # Terraform"
  exit 0
fi

echo "RESULT: FAIL — seed missing paths (see SECRETS.md Appendix B)"
echo "  ./vault/scripts/seed-secrets.sh   # from operator .env"
exit 1
