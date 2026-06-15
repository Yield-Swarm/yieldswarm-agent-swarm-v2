#!/usr/bin/env bash
# Shared helpers for Vault bootstrap scripts.
# shellcheck shell=bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
readonly REPO_ROOT
VAULT_DIR="${REPO_ROOT}/infra/vault"
# shellcheck disable=SC2034  # consumed by sourcing scripts
readonly VAULT_DIR

# ----- logging -----
_log() { printf '[vault-bootstrap][%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
log()  { _log "$*"; }
die()  { _log "FATAL: $*"; exit 1; }

# ----- preflight -----
require_bin() {
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 || die "missing required binary: $b"
  done
}

require_env() {
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || die "required env var not set: $v"
  done
}

# Default to the canonical KV mount, but allow override for testing.
: "${KV_MOUNT:=kv}"
: "${TRANSIT_MOUNT:=transit}"
: "${YS_ENV:=prod}"
export KV_MOUNT TRANSIT_MOUNT YS_ENV

vault_check() {
  require_bin vault jq
  require_env VAULT_ADDR
  # shellcheck disable=SC2153  # VAULT_ADDR comes from the operator environment
  vault status -format=json >/dev/null 2>&1 || die "cannot reach VAULT_ADDR=${VAULT_ADDR}"
}
