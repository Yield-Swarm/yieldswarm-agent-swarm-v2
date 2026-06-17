#!/usr/bin/env bash
# =============================================================================
# Shared helpers for YieldSwarm deployment scripts.
# Source this at the top of every deploy script:  source "$(dirname "$0")/lib.sh"
# =============================================================================
set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---- pretty logging --------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""
fi

log()   { printf '%s[%s]%s %s\n' "$C_BLUE"  "$(date +%H:%M:%S)" "$C_RESET" "$*"; }
ok()    { printf '%s[ ok ]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s[fail]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }
step()  { printf '\n%s==>%s %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }

# ---- config loading --------------------------------------------------------
# Loads deploy/config.env (deployment infra settings) and the root .env
# (application secrets) if they exist. Existing environment wins.
load_config() {
  local cfg="${REPO_ROOT}/deploy/config.env"
  if [[ -f "$cfg" ]]; then
    log "Loading deploy config: ${cfg}"
    set -a; # shellcheck disable=SC1090
    source "$cfg"; set +a
  else
    warn "deploy/config.env not found — using defaults/env. (cp deploy/config.env.example deploy/config.env)"
  fi
  local appenv="${REPO_ROOT}/.env"
  if [[ -f "$appenv" ]]; then
    set -a; # shellcheck disable=SC1090
    source "$appenv"; set +a
  fi
  local localenv="${REPO_ROOT}/.env.local"
  if [[ -f "$localenv" ]]; then
    set -a; # shellcheck disable=SC1090
    source "$localenv"; set +a
  fi

  # ---- defaults (only set when unset) ----
  : "${GHCR_OWNER:=}"
  : "${IMAGE_PREFIX:=yieldswarm}"
  : "${GHCR_USER:=${GHCR_OWNER}}"
  : "${IMAGE_TAG:=}"
  if [[ -z "${IMAGE_TAG}" ]]; then
    IMAGE_TAG="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo latest)"
  fi
  : "${REGISTRY:=ghcr.io}"

  : "${AKASH_KEY_NAME:=yieldswarm}"
  : "${AKASH_KEYRING_BACKEND:=os}"
  : "${AKASH_CHAIN_ID:=akashnet-2}"
  : "${AKASH_NODE:=https://rpc.akashnet.net:443}"
  : "${AKASH_GAS:=auto}"
  : "${AKASH_GAS_ADJUSTMENT:=1.5}"
  : "${AKASH_GAS_PRICES:=0.025uakt}"
  : "${AKASH_SDL:=deploy/akash/deploy.sdl.yaml}"
  : "${AKASH_MIN_BALANCE_UAKT:=5000000}"
  : "${AKASH_HEAL_INTERVAL:=60}"

  : "${TF_DIR:=deploy/terraform}"
  : "${TF_ENABLE_FLY:=false}"
  : "${TF_ENABLE_RENDER:=false}"
  : "${TF_ENABLE_HETZNER:=false}"

  : "${FRONTEND_CONFIG_OUT:=dashboard/config.js}"
  : "${WORKER_URLS:=}"

  : "${MONITORING_COMPOSE:=deploy/monitoring/docker-compose.yml}"
  : "${PROMETHEUS_PORT:=9090}"
  : "${GRAFANA_PORT:=3001}"
  : "${SOVEREIGN_LOOP_INTERVAL:=900}"
  : "${RUN_DIR:=.run}"

  export GHCR_OWNER IMAGE_PREFIX GHCR_USER IMAGE_TAG REGISTRY
  export AKASH_KEY_NAME AKASH_KEYRING_BACKEND AKASH_CHAIN_ID AKASH_NODE
  export AKASH_GAS AKASH_GAS_ADJUSTMENT AKASH_GAS_PRICES AKASH_SDL
  export AKASH_MIN_BALANCE_UAKT AKASH_HEAL_INTERVAL
  export TF_DIR TF_ENABLE_FLY TF_ENABLE_RENDER TF_ENABLE_HETZNER
  export FRONTEND_CONFIG_OUT WORKER_URLS
  export MONITORING_COMPOSE PROMETHEUS_PORT GRAFANA_PORT
  export SOVEREIGN_LOOP_INTERVAL RUN_DIR
}

# ---- utilities -------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

require() {
  local missing=0 c
  for c in "$@"; do
    if ! have "$c"; then err "missing required tool: $c"; missing=1; fi
  done
  [[ $missing -eq 0 ]] || die "install the missing tools above and retry"
}

# image_ref <component>  ->  ghcr.io/owner/prefix-component:tag
image_ref() {
  local component="$1"
  [[ -n "${GHCR_OWNER}" ]] || die "GHCR_OWNER is not set (see deploy/config.env)"
  printf '%s/%s/%s-%s:%s' \
    "${REGISTRY}" "${GHCR_OWNER,,}" "${IMAGE_PREFIX}" "${component}" "${IMAGE_TAG}"
}

ensure_run_dir() { mkdir -p "${REPO_ROOT}/${RUN_DIR}"; }
