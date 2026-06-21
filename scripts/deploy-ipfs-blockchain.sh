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
#   ./scripts/deploy-ipfs-blockchain.sh --dry-run    # stage + manifest only
#   ./scripts/deploy-ipfs-blockchain.sh --skip-build # reuse existing dist/
#   ./scripts/deploy-ipfs-blockchain.sh --verify     # verify gateway only
#   ./scripts/deploy-ipfs-blockchain.sh --help
#
# Requires (one of):
#   • ipfs (kubo) CLI, or Docker (uses ipfs/kubo image)
#   • PINATA_JWT or PINATA_API_KEY + PINATA_SECRET (for remote pin + fallback upload)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIFROST_LIB="${SCRIPT_DIR}/lib/bifrost_pin.py"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/deploy/scripts/lib.sh"

DRY_RUN=0
SKIP_BUILD=0
VERIFY_ONLY=0
SKIP_PINATA=0
ROOT_CID="${BIFROST_ROOT_CID:-}"

STAGING_DIR="${REPO_ROOT}/.run/bifrost-staging"
MANIFEST_OUT="${REPO_ROOT}/dashboard/bifrost-manifest.json"
IPFS_GATEWAY="${IPFS_GATEWAY:-https://gateway.pinata.cloud/ipfs}"
PIN_NAME="${BIFROST_PIN_NAME:-yieldswarm-bifrost-$(date +%Y%m%d)}"

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
    --cid)         ROOT_CID="$2"; shift 2 ;;
    --gateway)     IPFS_GATEWAY="$2"; shift 2 ;;
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
  log "Gateway:    ${IPFS_GATEWAY}"
  log "Manifest:   ${MANIFEST_OUT#${REPO_ROOT}/}"
  log "Dry run:    ${DRY_RUN}"
}

stage_static_realm() {
  step "Staging static realm for IPFS"
  rm -rf "${STAGING_DIR}"
  mkdir -p "${STAGING_DIR}/dashboard" "${STAGING_DIR}/frontend/dist" "${STAGING_DIR}/public"

  # Dashboards (command center, sovereign vault, static assets)
  if [[ -d "${REPO_ROOT}/dashboard" ]]; then
    rsync -a --exclude 'bifrost-staging' --exclude '.git' \
      "${REPO_ROOT}/dashboard/" "${STAGING_DIR}/dashboard/" 2>/dev/null \
      || cp -a "${REPO_ROOT}/dashboard/." "${STAGING_DIR}/dashboard/"
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
    if [[ "${DRY_RUN}" == "1" ]]; then
      warn "[dry-run] would run: npm run build:frontend"
    else
      require node npm
      (cd "${REPO_ROOT}/frontend" && npm run build)
    fi
  else
    warn "--skip-build: using existing frontend/dist if present"
  fi

  if [[ -d "${REPO_ROOT}/frontend/dist" ]]; then
    rsync -a "${REPO_ROOT}/frontend/dist/" "${STAGING_DIR}/frontend/dist/" 2>/dev/null \
      || cp -a "${REPO_ROOT}/frontend/dist/." "${STAGING_DIR}/frontend/dist/"
  else
    warn "frontend/dist missing — arena bundle will be omitted from staging"
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

  ok "Staged $(find "${STAGING_DIR}" -type f | wc -l | tr -d ' ') files → .run/bifrost-staging/"
}

verify_bridge() {
  step "Verifying Rainbow Bridge gateway"
  require python3
  if [[ ! -f "${MANIFEST_OUT}" ]]; then
    die "manifest not found: ${MANIFEST_OUT} — run deploy without --verify first"
  fi
  local cid gateway live
  cid="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['rootCid'])")"
  gateway="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['ipfsGateway'])")"
  if python3 "${BIFROST_LIB}" --staging "${STAGING_DIR}" \
      --manifest-out "${MANIFEST_OUT}" --repo-root "${REPO_ROOT}" \
      --gateway "${gateway}" --cid "${cid}" --dry-run >/dev/null 2>&1; then
    :
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
    ok "Gateway live: ${gateway}/${cid}/"
  else
    warn "Gateway not yet reachable (propagation may take minutes): ${gateway}/${cid}/"
  fi
  cat "${MANIFEST_OUT}"
}

pin_and_manifest() {
  step "Pinning to IPFS and forging bifrost-manifest.json"
  require python3

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
  result="$(python3 "${BIFROST_LIB}" "${py_args[@]}")"
  ok "Bridge manifest written"
  printf '%s\n' "$result"

  local cid
  cid="$(python3 -c "import json;print(json.load(open('${MANIFEST_OUT}'))['rootCid'])")"
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
  └───────────────────────────────────────────────────────────────
EOF
}

main() {
  load_config
  banner

  if [[ "${VERIFY_ONLY}" == "1" ]]; then
    verify_bridge
    exit 0
  fi

  stage_static_realm
  pin_and_manifest

  if [[ "${DRY_RUN}" == "0" ]]; then
    verify_bridge || true
  fi

  ok "Bifröst deployment complete"
}

main "$@"
