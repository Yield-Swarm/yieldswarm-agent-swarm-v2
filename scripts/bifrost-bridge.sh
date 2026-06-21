#!/usr/bin/env bash
# =============================================================================
# scripts/bifrost-bridge.sh — Bifröst cross-chain bridge runtime wrapper
#
# Invoked by bifrost-deploy.sh after lib pinning. Requires:
#   NEXUS_RPC_URL      — Nexus chain JSON-RPC endpoint
#   HELIX_BRIDGE_URL   — Helix cross-chain adapter (default: local backend)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Nexus RPC — primary chain telemetry + bridge anchor
NEXUS_RPC_URL="${NEXUS_RPC_URL:-}"

# Helix bridge API — routes harvest / treasury across solenoids
HELIX_BRIDGE_URL="${HELIX_BRIDGE_URL:-http://127.0.0.1:8080/api/helix}"

# IoTeX MachineFi key — optional treasury root verification
IOTEX_API_KEY="${IOTEX_API_KEY:-}"

log() { echo "[bifrost-bridge] $(date -u +%FT%TZ) $*"; }

if [[ -z "${NEXUS_RPC_URL}" ]]; then
  log "WARN: NEXUS_RPC_URL unset — bridge running in simulation mode"
fi

log "Bridge ready — helix=${HELIX_BRIDGE_URL} repo=${REPO_ROOT}"
exit 0
