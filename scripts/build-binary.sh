#!/usr/bin/env bash
# =============================================================================
# scripts/build-binary.sh — Compile release binaries for VM / production deploy
#
# Usage:
#   ./scripts/build-binary.sh              # Rust release binaries
#   ./scripts/build-binary.sh --frontend   # + Vite production bundle
#   ./scripts/build-binary.sh --all        # Rust + frontend
#
# Outputs (gitignored under bin/):
#   bin/swarm-core          — Layer 1 orchestrator (apps/swarm-core)
#   bin/binary-manifest.json — paths + versions for cross-threshold deploy
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

BIN_DIR="${REPO_ROOT}/bin"
MANIFEST="${BIN_DIR}/binary-manifest.json"
BUILD_FRONTEND=0

log() { printf '[build-binary] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frontend) BUILD_FRONTEND=1; shift ;;
    --all) BUILD_FRONTEND=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

command -v cargo >/dev/null 2>&1 || die "cargo not found — install Rust 1.86+ (see rust-toolchain.toml)"

mkdir -p "${BIN_DIR}"

log "Building Rust release binaries (workspace)"
cargo build --release -p swarm-core 2>&1 | tail -5

SWARM_CORE_SRC="${REPO_ROOT}/target/release/swarm-core"
[[ -f "${SWARM_CORE_SRC}" ]] || die "swarm-core binary not found at ${SWARM_CORE_SRC}"

cp -f "${SWARM_CORE_SRC}" "${BIN_DIR}/swarm-core"
chmod +x "${BIN_DIR}/swarm-core"

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
RUST_VER="$(rustc --version 2>/dev/null || echo unknown)"

cat > "${MANIFEST}" <<EOF
{
  "built_at": "$(date -u +%FT%TZ)",
  "git_sha": "${GIT_SHA}",
  "rust": "${RUST_VER}",
  "binaries": {
    "swarm_core": "${BIN_DIR}/swarm-core"
  }
}
EOF

log "swarm-core → ${BIN_DIR}/swarm-core ($(wc -c < "${BIN_DIR}/swarm-core") bytes)"
log "manifest  → ${MANIFEST}"

if [[ "${BUILD_FRONTEND}" == "1" ]]; then
  log "Building frontend production bundle"
  (cd frontend && npm install --silent && npm run build)
  log "frontend  → frontend/dist/"
fi

log "DONE — run: ${BIN_DIR}/swarm-core --help  (or wire via SWARM_CORE_BIN)"
