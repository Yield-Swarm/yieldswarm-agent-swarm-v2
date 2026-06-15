#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_SDL="$(mktemp)"

cleanup() {
  rm -f "${TMP_SDL}"
}

trap cleanup EXIT

: "${AKASH_IMAGE:?AKASH_IMAGE must be set}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_ROLE_ID:?VAULT_ROLE_ID must be set}"
: "${VAULT_SECRET_ID:?VAULT_SECRET_ID must be set}"
: "${VAULT_KV_MOUNT:=kv}"
: "${VAULT_SECRET_PATH:=runtime/akash/prod}"
: "${REQUIRED_SECRET_KEYS:=AGENTSWARM_MASTER_KEY,SOLANA_RPC_URL,RUNPOD_API_KEY,VULTR_API_KEY,DIGITALOCEAN_TOKEN}"
: "${AKASH_FROM:?AKASH_FROM must be set}"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required (install gettext)." >&2
  exit 1
fi

if ! command -v akash >/dev/null 2>&1; then
  echo "akash CLI is required." >&2
  exit 1
fi

envsubst < "${SCRIPT_DIR}/deployment.sdl.tpl" > "${TMP_SDL}"

akash tx deployment create "${TMP_SDL}" --from "${AKASH_FROM}"
