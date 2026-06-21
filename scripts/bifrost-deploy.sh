#!/usr/bin/env bash
# =============================================================================
# scripts/bifrost-deploy.sh — Bifröst bridge deployment (hardened)
#
# Usage:
#   ./scripts/bifrost-deploy.sh [--dry-run]
#
# Environment (see .env.example — Sovereign Loop section):
#   NEXUS_RPC_URL       — Nexus chain JSON-RPC endpoint for bridge telemetry
#   IOTEX_API_KEY       — IoTeX MachineFi API key for treasury root checks
#   VAULT_SECRET_TOKEN  — Vault token (optional; used when Vault inject is enabled)
#   SOVEREIGN_LOOP_KEY  — Sovereign loop signing key (optional)
#   HELIX_BRIDGE_URL    — Helix adapter URL (default http://127.0.0.1:8080/api/helix)
#
# Logs every step to .run/bifrost/deployment.log (gitignored).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Absolute path to shared shell helpers — defined ONCE (no duplicate BIFROST_LIB).
BIFROST_LIB="${SCRIPT_DIR}/lib"

# Create lib/ directory if it does not exist yet.
mkdir -p "${BIFROST_LIB}"

# Deployment audit log — append-only record of every step.
BIFROST_DEPLOY_LOG="${REPO_ROOT}/.run/bifrost/deployment.log"
mkdir -p "$(dirname "${BIFROST_DEPLOY_LOG}")"

# Bridge runtime script — verified executable at end of deploy.
BIFROST_BRIDGE_SCRIPT="${SCRIPT_DIR}/bifrost-bridge.sh"

# Python pin helper (snake_case module name: bifrost_pin.py).
BIFROST_PIN_SCRIPT="${SCRIPT_DIR}/bifrost_pin.py"

# Lock file written by bifrost_pin.py.
BIFROST_PIN_LOCK="${REPO_ROOT}/.run/bifrost/pin.lock.json"

# Dry-run mode — print actions without executing.
BIFROST_DRY_RUN=0

export BIFROST_LIB BIFROST_DEPLOY_LOG BIFROST_DRY_RUN

# shellcheck source=scripts/lib/bifrost.sh
source "${BIFROST_LIB}/bifrost.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/bifrost-deploy.sh [--dry-run]

  --dry-run   Show planned steps without modifying lock files or chmod
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      BIFROST_DRY_RUN=1
      export BIFROST_DRY_RUN
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      bifrost_die "Unknown argument: $1 (try --dry-run)"
      ;;
  esac
done

bifrost_log "=== Bifröst deploy start (dry_run=${BIFROST_DRY_RUN}) ==="

# Path validation — fail fast if required repo paths are missing.
bifrost_validate_paths \
  "${REPO_ROOT}" \
  "${BIFROST_LIB}" \
  "${BIFROST_LIB}/bifrost.sh" \
  "${BIFROST_PIN_SCRIPT}" \
  "${BIFROST_BRIDGE_SCRIPT}"

# Ensure bridge script is executable.
if [[ "${BIFROST_DRY_RUN}" == "1" ]]; then
  bifrost_log "[dry-run] would chmod +x ${BIFROST_BRIDGE_SCRIPT}"
else
  chmod +x "${BIFROST_BRIDGE_SCRIPT}"
  bifrost_log "Bridge script marked executable"
fi

# Pin library paths via Python helper.
PIN_ARGS=(python3 "${BIFROST_PIN_SCRIPT}" --lib-dir "${BIFROST_LIB}" --lock-file "${BIFROST_PIN_LOCK}")
if [[ "${BIFROST_DRY_RUN}" == "1" ]]; then
  PIN_ARGS+=(--dry-run)
fi
bifrost_run "${PIN_ARGS[@]}"

# Final check — bridge script must exist and be executable.
if [[ ! -f "${BIFROST_BRIDGE_SCRIPT}" ]]; then
  bifrost_die "Bifröst bridge script missing: ${BIFROST_BRIDGE_SCRIPT}"
fi

if [[ "${BIFROST_DRY_RUN}" == "1" ]]; then
  bifrost_log "[dry-run] would verify ${BIFROST_BRIDGE_SCRIPT} is executable"
else
  [[ -x "${BIFROST_BRIDGE_SCRIPT}" ]] || bifrost_die "Bridge script not executable: ${BIFROST_BRIDGE_SCRIPT}"
  bifrost_run "${BIFROST_BRIDGE_SCRIPT}"
fi

bifrost_log "=== Bifröst deploy complete ==="
