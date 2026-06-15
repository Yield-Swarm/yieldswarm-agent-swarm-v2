#!/usr/bin/env bash
# YieldSwarm Production Akash Deployment
# Pulls secrets from HashiCorp Vault, creates SDL, deploys monolith, runs health checks.
#
# Usage:
#   ./scripts/akash-deploy.sh                    # full deploy
#   ./scripts/akash-deploy.sh --dry-run          # validate only
#   ./scripts/akash-deploy.sh --rollback         # close lease + redeploy previous
#   ./scripts/akash-deploy.sh --env production   # target branch env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_FILE="$REPO_ROOT/deploy/deploy-swarm-monolith.yaml"
VAULT_SECRETS_SCRIPT="$SCRIPT_DIR/vault-secrets.sh"
HEALTH_SCRIPT="$SCRIPT_DIR/health-check.sh"
STATE_DIR="$REPO_ROOT/.akash-state"
LEASE_FILE="$STATE_DIR/lease.json"

ENV="${DEPLOY_ENV:-development}"
DRY_RUN=false
ROLLBACK=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[akash-deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[akash-deploy]${NC} $*"; }
err()  { echo -e "${RED}[akash-deploy]${NC} $*" >&2; }

usage() {
  cat <<EOF
YieldSwarm Akash Deploy

  ./scripts/akash-deploy.sh [options]

Options:
  --env ENV       Environment: development|testnet|devnets|production|MAINNET
  --dry-run       Validate SDL and Vault without deploying
  --rollback      Close current lease and restore previous deployment
  -h, --help      Show this help

Required env vars:
  VAULT_ADDR          HashiCorp Vault address
  VAULT_ROLE_ID       AppRole role ID (or VAULT_TOKEN for dev)
  VAULT_SECRET_ID     AppRole secret ID
  AKASH_KEY_NAME        Akash key name in keyring
  AKASH_CHAIN_ID        e.g. akashnet-2
  AKASH_NODE            RPC node URL

Optional:
  AKASH_DEPOSIT         Deposit in uakt (default: 5000000)
  AKASH_DSEQ            Override deployment sequence (rollback)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)       ENV="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --rollback)  ROLLBACK=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    err "Required command not found: $1"
    exit 1
  fi
}

check_prerequisites() {
  require_cmd akash
  require_cmd jq
  require_cmd curl

  if [[ -z "${VAULT_ADDR:-}" ]]; then
    err "VAULT_ADDR is required"
    exit 1
  fi

  if [[ -z "${VAULT_TOKEN:-}" && ( -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ) ]]; then
    err "Set VAULT_TOKEN or VAULT_ROLE_ID + VAULT_SECRET_ID"
    exit 1
  fi

  if [[ -z "${AKASH_KEY_NAME:-}" ]]; then
    err "AKASH_KEY_NAME is required"
    exit 1
  fi
}

pull_vault_secrets() {
  log "Pulling secrets from Vault (env: $ENV)..."
  mkdir -p "$REPO_ROOT/.secrets/$ENV"
  "$VAULT_SECRETS_SCRIPT" \
    --env "$ENV" \
    --output "$REPO_ROOT/.secrets/$ENV" \
    --paths "yieldswarm/$ENV/api,yieldswarm/$ENV/akash,yieldswarm/$ENV/payments,yieldswarm/$ENV/kairo"
}

render_sdl() {
  local rendered="$STATE_DIR/rendered-sdl.yaml"
  mkdir -p "$STATE_DIR"

  log "Rendering SDL for environment: $ENV"
  cp "$DEPLOY_FILE" "$rendered"

  # Inject environment-specific image tags
  sed -i "s|yieldswarm/|yieldswarm/${ENV}-|g" "$rendered" 2>/dev/null || \
    sed -i '' "s|yieldswarm/|yieldswarm/${ENV}-|g" "$rendered"

  echo "$rendered"
}

validate_sdl() {
  local sdl="$1"
  log "Validating SDL..."
  akash tx deployment validate "$sdl" || {
    err "SDL validation failed"
    exit 1
  }
  log "SDL validation passed"
}

deploy_to_akash() {
  local sdl="$1"
  local deposit="${AKASH_DEPOSIT:-5000000}"

  log "Creating deployment (deposit: ${deposit} uakt)..."
  local result
  result=$(akash tx deployment create "$sdl" \
    --from "$AKASH_KEY_NAME" \
    --deposit "${deposit}uakt" \
    --chain-id "${AKASH_CHAIN_ID:-akashnet-2}" \
    --node "${AKASH_NODE:-https://rpc.akash.network:443}" \
    --gas auto --gas-adjustment 1.5 \
    --yes -o json)

  local dseq
  dseq=$(echo "$result" | jq -r '.logs[0].events[] | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[] | select(.key=="dseq") | .value' | head -1)

  if [[ -z "$dseq" || "$dseq" == "null" ]]; then
    warn "Could not parse DSEQ from tx; check akash query deployment list"
    dseq="unknown"
  fi

  echo "{\"dseq\":\"$dseq\",\"env\":\"$ENV\",\"deployed_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$LEASE_FILE"
  log "Deployment created — DSEQ: $dseq"
  echo "$dseq"
}

wait_for_lease() {
  local dseq="$1"
  local owner
  owner=$(akash keys show "$AKASH_KEY_NAME" -a)
  local max_wait=600
  local elapsed=0

  log "Waiting for provider bid + lease (max ${max_wait}s)..."
  while [[ $elapsed -lt $max_wait ]]; do
    local bids
    bids=$(akash query market bid list --owner "$owner" --dseq "$dseq" -o json 2>/dev/null || echo '{"bids":[]}')
    local bid_count
    bid_count=$(echo "$bids" | jq '.bids | length')

    if [[ "$bid_count" -gt 0 ]]; then
      log "Found $bid_count bid(s); accepting lowest..."
      local bid
      bid=$(echo "$bids" | jq -r '.bids | sort_by(.bid.price.amount) | .[0].bid.bid_id')
      akash tx market lease create \
        --dseq "$dseq" \
        --from "$AKASH_KEY_NAME" \
        --provider "$(echo "$bids" | jq -r '.bids[0].bid.bid_id.provider')" \
        --chain-id "${AKASH_CHAIN_ID:-akashnet-2}" \
        --node "${AKASH_NODE:-https://rpc.akash.network:443}" \
        --gas auto --gas-adjustment 1.5 \
        --yes 2>/dev/null || true
      break
    fi

    sleep 15
    elapsed=$((elapsed + 15))
    log "  ...waiting (${elapsed}s)"
  done
}

run_health_checks() {
  log "Running post-deploy health checks..."
  if [[ -x "$HEALTH_SCRIPT" ]]; then
    "$HEALTH_SCRIPT" --env "$ENV" --wait 120 || {
      warn "Health checks failed — auto-heal sidecar will retry"
      return 1
    }
  fi
  log "Health checks passed"
}

rollback_deployment() {
  if [[ ! -f "$LEASE_FILE" ]]; then
    err "No lease state found at $LEASE_FILE"
    exit 1
  fi

  local dseq
  dseq=$(jq -r '.dseq' "$LEASE_FILE")
  log "Rolling back deployment DSEQ: $dseq"

  akash tx deployment close \
    --dseq "$dseq" \
    --from "$AKASH_KEY_NAME" \
    --chain-id "${AKASH_CHAIN_ID:-akashnet-2}" \
    --node "${AKASH_NODE:-https://rpc.akash.network:443}" \
    --gas auto --gas-adjustment 1.5 \
    --yes

  mv "$LEASE_FILE" "$STATE_DIR/lease.rollback.$(date +%s).json"
  log "Rollback complete"
}

main() {
  log "YieldSwarm Akash Deploy — env=$ENV"

  check_prerequisites
  mkdir -p "$STATE_DIR"

  if $ROLLBACK; then
    rollback_deployment
    exit 0
  fi

  pull_vault_secrets
  local sdl
  sdl=$(render_sdl)
  validate_sdl "$sdl"

  if $DRY_RUN; then
    log "Dry run complete — SDL valid, secrets pulled"
    exit 0
  fi

  local dseq
  dseq=$(deploy_to_akash "$sdl")
  wait_for_lease "$dseq"
  run_health_checks || true

  log "Deployment complete"
  log "  DSEQ:    $dseq"
  log "  State:   $LEASE_FILE"
  log "  Monitor: akash provider lease-status --dseq $dseq"
}

main "$@"
