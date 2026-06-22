#!/usr/bin/env bash
# =============================================================================
# run-all-onchain.sh — Unified Helix + onchain activation (npm run run-all-onchain)
#
# Replaces the legacy "run-all-onchain" npm key used in operator playbooks.
# Sequence: onchain build (optional) → Helix genesis → backend → sovereign loops
#
# Usage:
#   ./scripts/run-all-onchain.sh
#   ./scripts/run-all-onchain.sh --dry-run
#   START_MINING=1 ./scripts/run-all-onchain.sh
#   SKIP_ANCHOR=1 ./scripts/run-all-onchain.sh   # skip anchor build on mobile nodes
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
SKIP_ANCHOR="${SKIP_ANCHOR:-0}"
START_MINING="${START_MINING:-0}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-anchor) SKIP_ANCHOR=1 ;;
    --with-mining) START_MINING=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

log() { printf '[run-all-onchain] %s\n' "$*"; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY RUN plan:"
  echo "  1. onchain: anchor build (if anchor installed and SKIP_ANCHOR!=1)"
  echo "  2. ./scripts/activate-helix.sh"
  echo "  3. optional: ./scripts/mining/start-all.sh (START_MINING=1)"
  echo "  4. verify: curl /api/helix/status"
  exit 0
fi

log "Step 1/3 — Onchain programs (Anchor)"
if [[ "$SKIP_ANCHOR" == "1" ]]; then
  log "SKIP_ANCHOR=1 — skipping anchor build (use on Termux/mobile nodes)"
elif command -v anchor >/dev/null 2>&1; then
  (cd onchain && anchor build) || log "WARN: anchor build failed — continuing with Helix activation"
else
  log "anchor CLI not found — skip (install Anchor 0.30.1 for full onchain compile)"
fi

log "Step 2/3 — Helix Chain activation"
bash "${REPO_ROOT}/scripts/activate-helix.sh"

log "Step 3/3 — Post-activation"
if [[ "$START_MINING" == "1" ]]; then
  log "Starting mining fleet (START_MINING=1)"
  bash "${REPO_ROOT}/scripts/mining/start-all.sh" || log "WARN: mining start returned non-zero"
fi

BACKEND_PORT="${PORT:-8080}"
if curl -sf "http://127.0.0.1:${BACKEND_PORT}/api/helix/status" >/dev/null 2>&1; then
  log "Helix status OK — http://127.0.0.1:${BACKEND_PORT}/api/helix/status"
else
  log "Helix API not reachable on port ${BACKEND_PORT} — check .run/backend.log"
fi

log "Done. Mobile hotspot fleet: repeat with unique GRASS_NODE_KEYS per node."
