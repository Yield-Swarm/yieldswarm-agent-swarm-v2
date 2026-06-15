#!/usr/bin/env bash
# Pull secrets from HashiCorp Vault and render to filesystem for container injection.
#
# Usage:
#   ./scripts/vault-secrets.sh --env production --output ./.secrets/production
#   ./scripts/vault-secrets.sh --render /run/secrets   # used inside Akash container

set -euo pipefail

ENV="${VAULT_ENV:-development}"
OUTPUT_DIR=""
RENDER_DIR=""
VAULT_PATHS="yieldswarm/${ENV}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[vault-secrets]${NC} $*"; }
err() { echo -e "${RED}[vault-secrets]${NC} $*" >&2; }

authenticate() {
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    export VAULT_TOKEN
    return
  fi

  if [[ -n "${VAULT_ROLE_ID:-}" && -n "${VAULT_SECRET_ID:-}" ]]; then
    log "Authenticating via AppRole..."
    VAULT_TOKEN=$(vault write -field=token auth/approle/login \
      role_id="$VAULT_ROLE_ID" \
      secret_id="$VAULT_SECRET_ID")
    export VAULT_TOKEN
    return
  fi

  err "No Vault credentials. Set VAULT_TOKEN or VAULT_ROLE_ID + VAULT_SECRET_ID"
  exit 1
}

fetch_secret() {
  local path="$1"
  local dest="$2"

  log "Fetching secret/$path → $dest"
  mkdir -p "$(dirname "$dest")"

  if vault kv get -format=json "secret/$path" &>/dev/null; then
    vault kv get -format=json "secret/$path" | \
      jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"' > "$dest"
  elif vault kv get -format=json "$path" &>/dev/null; then
    vault kv get -format=json "$path" | \
      jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"' > "$dest"
  else
    warn_path="$path"
    log "  (path not found: $warn_path — using placeholder)"
    echo "# placeholder for $path" > "$dest"
  fi

  chmod 600 "$dest"
}

render_all() {
  local base="$1"
  mkdir -p "$base"

  authenticate

  IFS=',' read -ra PATHS <<< "${VAULT_PATHS_OVERRIDE:-$VAULT_PATHS}"
  for path in "${PATHS[@]}"; do
  path=$(echo "$path" | xargs)
    local filename
    filename=$(echo "$path" | tr '/' '_')
    fetch_secret "$path" "$base/${filename}.env"
  done

  # Consolidated env file for services that read SECRETS_DIR
  cat "$base"/*.env 2>/dev/null > "$base/consolidated.env" || true
  chmod 600 "$base/consolidated.env"

  log "Secrets rendered to $base"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)    ENV="$2"; VAULT_PATHS="yieldswarm/$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --render) RENDER_DIR="$2"; shift 2 ;;
    --paths)  VAULT_PATHS_OVERRIDE="$2"; shift 2 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -n "$RENDER_DIR" ]]; then
  render_all "$RENDER_DIR"
elif [[ -n "$OUTPUT_DIR" ]]; then
  render_all "$OUTPUT_DIR"
else
  err "Specify --output DIR or --render DIR"
  exit 1
fi
