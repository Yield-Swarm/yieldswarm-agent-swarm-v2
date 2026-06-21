#!/usr/bin/env bash
# =============================================================================
# Bifröst — deploy-ipfs-blockchain.sh
# Rainbow Bridge: local static realm → IPFS pin → multi-chain gateway manifest
#
# Restores the sacred connection between:
#   • Local build artifacts (frontend + dashboards)
#   • Pinata / IPFS pinned site (immutable CID)
#   • Blockchain identity realms (Helix / Nexus / Shadow .blockchain hosts)
#
# Usage:
#   ./scripts/deploy-ipfs-blockchain.sh              # full bridge restore
#   ./scripts/deploy-ipfs-blockchain.sh --dry-run    # show paths + plan only
#   ./scripts/deploy-ipfs-blockchain.sh --skip-build # reuse existing dist/
#   ./scripts/deploy-ipfs-blockchain.sh --verify     # verify gateway only
#   ./scripts/deploy-ipfs-blockchain.sh --help
#
# Requires (one of):
#   • ipfs (kubo) CLI, or Docker (uses ipfs/kubo image)
#   • PINATA_JWT or PINATA_API_KEY + PINATA_SECRET (for remote pin + fallback upload)
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Path resolution (must run before sourcing lib.sh — lib.sh overwrites SCRIPT_DIR)
# -----------------------------------------------------------------------------

# SCRIPT_DIR — absolute path to scripts/ (this file's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# REPO_ROOT — monorepo root (parent of scripts/)
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# BIFROST_SCRIPT — this deploy entrypoint (saved before lib.sh overwrites SCRIPT_DIR)
BIFROST_SCRIPT="${SCRIPT_DIR}/deploy-ipfs-blockchain.sh"

# BIFROST_LIB — Python pin/manifest helper (underscore per Python convention)
BIFROST_LIB="${SCRIPT_DIR}/lib/bifrost_pin.py"

# DEPLOY_LOG — timestamped audit trail for every deploy step
DEPLOY_LOG="${REPO_ROOT}/.run/deployment.log"

# STAGING_DIR — ephemeral static site bundle uploaded to IPFS
STAGING_DIR="${REPO_ROOT}/.run/bifrost-staging"

# MANIFEST_OUT — generated realm → gateway map (gitignored)
MANIFEST_OUT="${REPO_ROOT}/dashboard/bifrost-manifest.json"

# Runtime flags (mutated by CLI args below)
DRY_RUN=0
SKIP_BUILD=0
VERIFY_ONLY=0
SKIP_PINATA=0
ROOT_CID="${BIFROST_ROOT_CID:-}"

# IPFS_GATEWAY — public resolver base for pinned content
IPFS_GATEWAY="${IPFS_GATEWAY:-https://gateway.pinata.cloud/ipfs}"

# PIN_NAME — Pinata metadata label for this deployment
PIN_NAME="${BIFROST_PIN_NAME:-yieldswarm-bifrost-$(date +%Y%m%d)}"

# -----------------------------------------------------------------------------
# Logging helpers (deployment.log + console)
# -----------------------------------------------------------------------------

log_deploy() {
  local level="$1"
  shift
  local ts msg
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  msg="[${ts}] [${level}] $*"
  mkdir -p "$(dirname "${DEPLOY_LOG}")"
  printf '%s\n' "${msg}" >> "${DEPLOY_LOG}"
  case "${level}" in
    ERROR) err "$*" ;;
    WARN)  warn "$*" ;;
    OK)    ok "$*" ;;
    *)     log "$*" ;;
  esac
}

# -----------------------------------------------------------------------------
# Safety checks — validate paths before any deployment work
# -----------------------------------------------------------------------------

ensure_lib_directory() {
  # Item 4: guarantee scripts/lib/ exists before referencing bifrost_pin.py
  if [[ ! -d "${SCRIPT_DIR}/lib" ]]; then
    log_deploy "INFO" "creating missing lib directory: ${SCRIPT_DIR}/lib"
    mkdir -p "${SCRIPT_DIR}/lib"
  fi
}

validate_paths() {
  # Item 6: SCRIPT_DIR and REPO_ROOT must exist and be readable
  if [[ ! -d "${SCRIPT_DIR}" ]]; then
    log_deploy "ERROR" "SCRIPT_DIR does not exist: ${SCRIPT_DIR}"
    exit 1
  fi
  if [[ ! -r "${SCRIPT_DIR}" ]]; then
    log_deploy "ERROR" "SCRIPT_DIR is not readable: ${SCRIPT_DIR}"
    exit 1
  fi
  if [[ ! -d "${REPO_ROOT}" ]]; then
    log_deploy "ERROR" "REPO_ROOT does not exist: ${REPO_ROOT}"
    exit 1
  fi
  if [[ ! -f "${REPO_ROOT}/package.json" ]]; then
    log_deploy "ERROR" "REPO_ROOT does not look like YieldSwarm root (missing package.json): ${REPO_ROOT}"
    exit 1
  fi
  if [[ ! -f "${BIFROST_LIB}" ]]; then
    log_deploy "ERROR" "BIFROST_LIB helper missing: ${BIFROST_LIB}"
    exit 1
  fi
  if [[ ! -x "${BIFROST_SCRIPT}" ]] && [[ -f "${BIFROST_SCRIPT}" ]]; then
    log_deploy "WARN" "deploy-ipfs-blockchain.sh is not executable — run: chmod +x scripts/deploy-ipfs-blockchain.sh"
  fi
}

is_gitignored() {
  # Item 8: consult .gitignore before writing generated artifacts
  local path="$1"
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi
  git -C "${REPO_ROOT}" check-ignore -q "${path}" 2>/dev/null
}

assert_safe_output_path() {
  local path="$1"
  local rel="${path#${REPO_ROOT}/}"

  # Never overwrite secrets or deploy credentials
  case "${rel}" in
    .env|deploy/config.env|*.pem|*secret*|*credentials*)
      log_deploy "ERROR" "refusing to write sensitive path: ${rel}"
      exit 1
      ;;
  esac

  if is_gitignored "${rel}"; then
    log_deploy "INFO" "output path is gitignored (safe): ${rel}"
  else
    log_deploy "WARN" "output path is NOT gitignored — verify before commit: ${rel}"
  fi
}

print_dry_run_plan() {
  # Item 7: show computed paths and planned actions without side effects
  step "DRY-RUN PLAN — no mutations will be applied"
  cat <<EOF
  SCRIPT_DIR     = ${SCRIPT_DIR}
  REPO_ROOT      = ${REPO_ROOT}
  BIFROST_LIB    = ${BIFROST_LIB}
  DEPLOY_LOG     = ${DEPLOY_LOG}
  STAGING_DIR    = ${STAGING_DIR}
  MANIFEST_OUT   = ${MANIFEST_OUT}
  IPFS_GATEWAY   = ${IPFS_GATEWAY}
  PIN_NAME       = ${PIN_NAME}
  ROOT_CID       = ${ROOT_CID:-<computed>}
  SKIP_BUILD     = ${SKIP_BUILD}
  SKIP_PINATA    = ${SKIP_PINATA}

  Planned actions:
    1. validate paths + lib directory
    2. stage dashboard/, static HTML, frontend/dist → STAGING_DIR
    3. run bifrost_pin.py (placeholder CID in dry-run)
    4. write MANIFEST_OUT + dashboard/config.js
    5. append audit lines to DEPLOY_LOG
    6. final validation of deploy-ipfs-blockchain.sh
EOF
  log_deploy "INFO" "dry-run plan emitted"
}

final_validation() {
  # Item 10: confirm bridge script exists and is executable
  step "Final validation"
  local self="${BIFROST_SCRIPT}"
  if [[ ! -f "${self}" ]]; then
    log_deploy "ERROR" "Bifröst bridge script missing: ${self}"
    return 1
  fi
  if [[ ! -x "${self}" ]]; then
    log_deploy "ERROR" "Bifröst bridge script not executable: ${self}"
    return 1
  fi
  if [[ ! -f "${BIFROST_LIB}" ]]; then
    log_deploy "ERROR" "BIFROST_LIB missing after deploy: ${BIFROST_LIB}"
    return 1
  fi
  if [[ "${DRY_RUN}" == "0" && ! -f "${MANIFEST_OUT}" ]]; then
    log_deploy "ERROR" "manifest not written: ${MANIFEST_OUT}"
    return 1
  fi
  log_deploy "OK" "final validation passed — bridge script executable, helper present"
  return 0
}

# Shared deploy helpers from deploy/scripts/lib.sh (logging, load_config, require, …)
source "${REPO_ROOT}/deploy/scripts/lib.sh"

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1; shift ;;
    --skip-build)  SKIP_BUILD=1; shift ;;
    --skip-pinata) SKIP_PINATA=1; shift ;;
    --verify)      VERIFY_ONLY=1; shift ;;
    --cid)         ROOT_CID="${2:?--cid requires a value}"; shift 2 ;;
    --gateway)     IPFS_GATEWAY="${2:?--gateway requires a value}"; shift 2 ;;
    -h|--help)     usage 0 ;;
    *)             die "unknown arg: $1 (try --help)" ;;
  esac
done

banner() {
  cat <<'EOF'

  ╔══════════════════════════════════════════════════════════════╗
  ║  Bifröst — Rainbow Bridge Deployment                         ║
  ║  Local realm  →  IPFS pin  →  Helix / Nexus / Shadow gates   ║
  ╚══════════════════════════════════════════════════════════════╝
EOF
  log_deploy "INFO" "gateway=${IPFS_GATEWAY} dry_run=${DRY_RUN} log=${DEPLOY_LOG}"
  log "Gateway:    ${IPFS_GATEWAY}"
  log "Manifest:   ${MANIFEST_OUT#${REPO_ROOT}/}"
  log "Deploy log: ${DEPLOY_LOG#${REPO_ROOT}/}"
  log "Dry run:    ${DRY_RUN}"
}

require_directory() {
  local dir="$1"
  local label="$2"
  if [[ ! -d "${dir}" ]]; then
    log_deploy "ERROR" "${label} directory missing: ${dir}"
    exit 1
  fi
}

stage_static_realm() {
  step "Staging static realm for IPFS"
  log_deploy "INFO" "staging start → ${STAGING_DIR}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    mkdir -p "${STAGING_DIR}"
    warn "[dry-run] skipped full staging — would sync dashboard/, static HTML, frontend/dist"
    log_deploy "INFO" "dry-run staging placeholder at ${STAGING_DIR}"
    return 0
  fi

  rm -rf "${STAGING_DIR}"
  mkdir -p "${STAGING_DIR}/dashboard" "${STAGING_DIR}/frontend/dist" "${STAGING_DIR}/public"

  # Dashboards — exclude secrets and generated gitignored artifacts
  if [[ -d "${REPO_ROOT}/dashboard" ]]; then
    rsync -a \
      --exclude 'bifrost-staging' \
      --exclude '.git' \
      --exclude 'bifrost-manifest.json' \
      --exclude 'config.js' \
      --exclude '.env' \
      "${REPO_ROOT}/dashboard/" "${STAGING_DIR}/dashboard/" 2>/dev/null \
      || cp -a "${REPO_ROOT}/dashboard/." "${STAGING_DIR}/dashboard/"
  else
    log_deploy "WARN" "dashboard/ not found — skipping dashboard staging"
  fi

  # Root static surfaces
  for f in index.html public/index.html council/status.html; do
    if [[ -f "${REPO_ROOT}/${f}" ]]; then
      local dest="${STAGING_DIR}/${f}"
      mkdir -p "$(dirname "$dest")"
      cp "${REPO_ROOT}/${f}" "$dest"
    fi
  done

  # Frontend production build
  if [[ "${SKIP_BUILD}" == "0" ]]; then
    step "Building frontend (Vite)"
    require_directory "${REPO_ROOT}/frontend" "frontend"
    require node npm
    (cd "${REPO_ROOT}/frontend" && npm run build) \
      || { log_deploy "ERROR" "frontend build failed"; exit 1; }
  else
    warn "--skip-build: using existing frontend/dist if present"
  fi

  if [[ -d "${REPO_ROOT}/frontend/dist" ]]; then
    rsync -a "${REPO_ROOT}/frontend/dist/" "${STAGING_DIR}/frontend/dist/" 2>/dev/null \
      || cp -a "${REPO_ROOT}/frontend/dist/." "${STAGING_DIR}/frontend/dist/"
  else
    log_deploy "WARN" "frontend/dist missing — arena bundle omitted from staging"
  fi

  # Bridge index — entry point for IPFS gateway visitors
  cat > "${STAGING_DIR}/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <meta name="theme-color" content="#000000"/>
  <title>YieldSwarm — Bifröst Gateway</title>
  <meta http-equiv="refresh" content="0;url=dashboard/command-center.html"/>
</head>
<body style="background:#000;color:#ff00c8;font-family:monospace;padding:2rem">
  <p>Crossing the Rainbow Bridge…</p>
  <p><a href="dashboard/command-center.html" style="color:#00e676">Enter Command Center</a></p>
</body>
</html>
HTML

  local file_count
  file_count="$(find "${STAGING_DIR}" -type f | wc -l | tr -d ' ')"
  log_deploy "OK" "staged ${file_count} files → ${STAGING_DIR}"
  ok "Staged ${file_count} files → .run/bifrost-staging/"
}

verify_bridge() {
  step "Verifying Rainbow Bridge gateway"
  require python3

  if [[ ! -f "${MANIFEST_OUT}" ]]; then
    log_deploy "ERROR" "manifest not found: ${MANIFEST_OUT}"
    die "manifest not found: ${MANIFEST_OUT} — run deploy without --verify first"
  fi

  local cid gateway live
  cid="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['rootCid'])")"
  gateway="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['ipfsGateway'])")"

  if [[ "${DRY_RUN}" == "1" ]]; then
    warn "[dry-run] would verify gateway: ${gateway}/${cid}/"
    return 0
  fi

  live="$(python3 - <<PY
import json, urllib.request
m = json.load(open("${MANIFEST_OUT}"))
cid = m["rootCid"]
gw = m["ipfsGateway"].rstrip("/")
url = f"{gw}/{cid}/"
try:
    with urllib.request.urlopen(url, timeout=15) as r:
        print("ok" if r.status < 400 else "fail")
except Exception:
    print("fail")
PY
)"
  if [[ "$live" == "ok" ]]; then
    log_deploy "OK" "gateway live ${gateway}/${cid}/"
    ok "Gateway live: ${gateway}/${cid}/"
  else
    log_deploy "WARN" "gateway not reachable ${gateway}/${cid}/"
    warn "Gateway not yet reachable (propagation may take minutes): ${gateway}/${cid}/"
  fi
  cat "${MANIFEST_OUT}"
}

pin_and_manifest() {
  step "Pinning to IPFS and forging bifrost-manifest.json"
  require python3

  assert_safe_output_path "${MANIFEST_OUT}"
  assert_safe_output_path "${REPO_ROOT}/dashboard/config.js"

  if [[ "${DRY_RUN}" == "1" ]]; then
    warn "[dry-run] would run: python3 ${BIFROST_LIB} --staging ${STAGING_DIR} ..."
    mkdir -p "${STAGING_DIR}"
    mkdir -p "$(dirname "${MANIFEST_OUT}")"
  fi

  local py_args=(
    --staging "${STAGING_DIR}"
    --manifest-out "${MANIFEST_OUT}"
    --repo-root "${REPO_ROOT}"
    --gateway "${IPFS_GATEWAY}"
    --local-api "${API_BASE:-http://127.0.0.1:8080}"
    --build-tag "${IMAGE_TAG}"
    --pin-name "${PIN_NAME}"
  )
  [[ "${DRY_RUN}" == "1" ]] && py_args+=(--dry-run)
  [[ "${SKIP_PINATA}" == "1" ]] && py_args+=(--skip-pinata)
  [[ -n "${ROOT_CID}" ]] && py_args+=(--cid "${ROOT_CID}")

  if [[ -z "${PINATA_JWT:-}" && -z "${PINATA_API_KEY:-}" ]]; then
    warn "PINATA_JWT unset — will use local ipfs/docker add only (no Pinata pinByHash)"
    py_args+=(--skip-pinata)
  fi

  local result
  if ! result="$(python3 "${BIFROST_LIB}" "${py_args[@]}")"; then
    log_deploy "ERROR" "bifrost_pin.py failed"
    exit 1
  fi

  log_deploy "OK" "manifest written ${MANIFEST_OUT}"
  ok "Bridge manifest written"
  printf '%s\n' "$result"

  local cid
  cid="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['rootCid'])")"
  log_deploy "INFO" "rootCid=${cid}"
  cat <<EOF

  ┌─ Rainbow Bridge RESTORED ─────────────────────────────────────
  │ Root CID:  ${cid}
  │ Gateway:   ${IPFS_GATEWAY}/${cid}/
  │ Realms:
  │   yieldswarm.xyz          → pinned root
  │   helixchain.blockchain   → command-center
  │   nexuschain.blockchain   → sovereign-dashboard
  │   shadowchain.blockchain  → public index
  │ Local API bridge: ${API_BASE:-http://127.0.0.1:8080}
  │ Manifest: dashboard/bifrost-manifest.json
  │ Runtime:   dashboard/config.js (window.YIELDSWARM_CONFIG.bifrost)
  │ Audit log: .run/deployment.log
  └───────────────────────────────────────────────────────────────
EOF
}

main() {
  ensure_lib_directory
  validate_paths
  load_config

  if [[ "${DRY_RUN}" == "1" && "${VERIFY_ONLY}" == "0" ]]; then
    banner
    print_dry_run_plan
    stage_static_realm
    pin_and_manifest
    final_validation
    ok "Bifröst dry-run complete — see .run/deployment.log"
    exit 0
  fi

  banner

  if [[ "${VERIFY_ONLY}" == "1" ]]; then
    verify_bridge
    final_validation
    exit 0
  fi

  stage_static_realm
  pin_and_manifest

  if [[ "${DRY_RUN}" == "0" ]]; then
    verify_bridge || true
  fi

  final_validation
  log_deploy "OK" "Bifröst deployment complete"
  ok "Bifröst deployment complete"
}

main "$@"
