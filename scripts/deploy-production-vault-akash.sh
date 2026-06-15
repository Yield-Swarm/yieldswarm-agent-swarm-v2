#!/usr/bin/env bash
# scripts/deploy-production-vault-akash.sh
#
# Production deployment orchestrator: Vault secrets → Akash RTX 3090 workers →
# health verification → auto-healing daemon.
#
# All secrets are pulled from HashiCorp Vault at runtime. Nothing sensitive is
# written to disk beyond tmpfs-rendered env files inside Akash containers.
#
# Prerequisites:
#   - Vault bootstrapped (vault/setup/bootstrap.sh)
#   - Akash wallet funded (AKASH_KEY_NAME)
#   - deploy/config.env filled in
#
# Usage:
#   ./scripts/deploy-production-vault-akash.sh              # full deploy
#   ./scripts/deploy-production-vault-akash.sh --check      # preflight only
#   ./scripts/deploy-production-vault-akash.sh --heal-only  # start heal daemon
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/vault-env.sh
source "${ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || true

log()  { printf '\033[1;36m[vault-akash]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[vault-akash]\033[0m %s\n' "$*" >&2; exit 1; }

MODE="${1:-deploy}"

# ---------------------------------------------------------------------------
# Step 0: load config
# ---------------------------------------------------------------------------
[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

VAULT_ADDR="${VAULT_ADDR:-}"
AKASH_SDL="${AKASH_SDL:-deploy/deploy-swarm-monolith.yaml}"
AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
preflight() {
  log "Running preflight checks…"
  command -v vault >/dev/null 2>&1 || die "vault CLI not found"
  command -v jq >/dev/null 2>&1 || die "jq not found"
  [[ -n "$VAULT_ADDR" ]] || die "VAULT_ADDR not set"
  [[ -f "$AKASH_SDL" ]] || die "SDL not found: $AKASH_SDL"

  log "Checking Vault connectivity…"
  vault status >/dev/null 2>&1 || die "Cannot reach Vault at $VAULT_ADDR"

  log "Checking Akash CLI…"
  ./scripts/akash-deploy.sh check

  log "Verifying Akash runtime secrets in Vault…"
  vault kv get -format=json "kv/data/yieldswarm/akash/runtime" >/dev/null 2>&1 \
    || log "WARN: kv/yieldswarm/akash/runtime not seeded yet — run vault/setup/bootstrap.sh"

  log "Preflight passed."
}

# ---------------------------------------------------------------------------
# Step 1: pull deploy secrets from Vault
# ---------------------------------------------------------------------------
load_vault_secrets() {
  log "Loading Akash deploy secrets from Vault…"
  local path="${AKASH_DEPLOY_VAULT_PATH:-kv/data/yieldswarm/akash/deploy}"
  if command -v vault_export_env >/dev/null 2>&1; then
    vault_export_env "$path"
  else
    log "vault_export_env not available; using manual export"
    eval "$(vault kv get -format=json "$path" | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value|@sh)"')"
  fi
}

# ---------------------------------------------------------------------------
# Step 2: deploy Akash workers with Vault-wrapped SecretID
# ---------------------------------------------------------------------------
deploy_akash() {
  log "Creating Akash deployment from $AKASH_SDL…"

  # Wrap a fresh SecretID for the akash-runtime AppRole (one-shot, short TTL).
  local secret_id
  secret_id=$(vault write -field=secret_id -f "auth/approle/role/akash-runtime/secret-id")
  local wrapped
  wrapped=$(vault write -field=wrapping_token -wrap-ttl=120s "auth/approle/role/akash-runtime/secret-id" secret_id="$secret_id" 2>/dev/null \
    || vault token create -wrap-ttl=120s -field=wrapping_token)

  export VAULT_WRAPPED_SECRET_ID="$wrapped"
  export VAULT_ROLE_ID="${VAULT_ROLE_ID:-$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)}"
  export AGENT_SHARD_ID="${AGENT_SHARD_ID:-0}"

  local result
  result=$(./scripts/akash-deploy.sh deploy "$AKASH_SDL")
  echo "$result" | tee .run/akash-lease.json

  local uri
  uri=$(echo "$result" | jq -r '.uri // .uris[0] // empty')
  [[ -n "$uri" ]] || die "Deploy succeeded but no URI returned"

  log "Worker deployed: $uri"
  echo "AKASH_WORKER_URI=$uri" > .run/akash-lease.env
}

# ---------------------------------------------------------------------------
# Step 3: health check
# ---------------------------------------------------------------------------
health_check() {
  local uri="${1:-}"
  [[ -n "$uri" ]] || { [[ -f .run/akash-lease.env ]] && source .run/akash-lease.env; uri="${AKASH_WORKER_URI:-}"; }
  [[ -n "$uri" ]] || die "No worker URI for health check"

  log "Health-checking $uri/healthz …"
  local attempt=0
  while (( attempt < 30 )); do
    if curl -fsS --max-time 10 "${uri}/healthz" >/dev/null 2>&1; then
      log "Worker healthy after ${attempt} attempts."
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  die "Worker failed health check after 5 minutes."
}

# ---------------------------------------------------------------------------
# Step 4: start auto-healing daemon
# ---------------------------------------------------------------------------
start_heal_daemon() {
  log "Starting Akash lease auto-heal daemon…"
  if [[ -f deploy/akash/auto-heal.sh ]]; then
    deploy/akash/auto-heal.sh --daemon &
    echo $! > .run/akash-heal.pid
    log "Heal daemon PID $(cat .run/akash-heal.pid)"
  elif [[ -f akash/lease-manager.py ]]; then
    python3 akash/lease-manager.py --daemon &
    echo $! > .run/akash-heal.pid
    log "Lease manager daemon PID $(cat .run/akash-heal.pid)"
  else
    log "WARN: no auto-heal script found; skipping."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
mkdir -p .run

case "$MODE" in
  --check|check)
    preflight
    ;;
  --heal-only|heal)
    start_heal_daemon
    ;;
  deploy|--deploy|"")
    preflight
    load_vault_secrets
    deploy_akash
    health_check
    start_heal_daemon
    log "Production Akash + Vault deployment complete."
    log "Worker URI: $(cat .run/akash-lease.env 2>/dev/null || echo 'see .run/akash-lease.json')"
    ;;
  *)
    die "Unknown mode: $MODE (use: deploy | --check | --heal-only)"
    ;;
esac
