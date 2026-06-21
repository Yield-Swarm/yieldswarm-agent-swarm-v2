#!/usr/bin/env bash
# =============================================================================
# scripts/lib/bifrost.sh — shared helpers for Bifröst bridge deployment
# Sourced by scripts/bifrost-deploy.sh (do not invoke directly).
# =============================================================================
set -euo pipefail

# Absolute path to scripts/lib (set once by bifrost-deploy.sh before sourcing).
: "${BIFROST_LIB:?BIFROST_LIB must be set by the caller}"

bifrost_log() {
  local msg="[bifrost] $*"
  echo "$msg"
  if [[ -n "${BIFROST_DEPLOY_LOG:-}" ]]; then
    echo "$(date -u +%FT%TZ) $msg" >> "${BIFROST_DEPLOY_LOG}"
  fi
}

bifrost_die() {
  bifrost_log "ERROR: $*"
  exit 1
}

# Validate required directories exist before deploy steps run.
bifrost_validate_paths() {
  local missing=0
  for path in "$@"; do
    if [[ ! -e "$path" ]]; then
      bifrost_log "MISSING PATH: $path"
      missing=$((missing + 1))
    fi
  done
  [[ "$missing" -eq 0 ]] || bifrost_die "$missing required path(s) not found"
}

bifrost_run() {
  if [[ "${BIFROST_DRY_RUN:-0}" == "1" ]]; then
    bifrost_log "[dry-run] would run: $*"
    return 0
  fi
  bifrost_log "RUN: $*"
  "$@"
}
