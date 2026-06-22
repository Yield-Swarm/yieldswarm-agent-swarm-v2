#!/usr/bin/env bash
# Bootstrap YieldSwarm mining on Azure Cloud Shell, Termux, or any fresh shell in ~.
#
# Fixes: wrong directory, missing deploy/akash.env, missing mining/README.
#
# Usage:
#   curl -fsSL ... | bash   # or clone first, then:
#   ./scripts/bootstrap-mining-shell.sh
set -euo pipefail

REPO_DIR="${YIELDSWARM_REPO:-$HOME/yieldswarm-agent-swarm-v2}"
REPO_URL="${YIELDSWARM_REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"

log() { printf '[bootstrap] %s\n' "$*" >&2; }

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  log "Cloning ${REPO_URL} → ${REPO_DIR}"
  git clone "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"
log "repo: $(pwd)"

git fetch origin production 2>/dev/null || git fetch origin main 2>/dev/null || true
if git show-ref --verify --quiet refs/remotes/origin/production; then
  git checkout production 2>/dev/null || git checkout -b production origin/production
  git pull origin production 2>/dev/null || true
fi

mkdir -p deploy mining scripts .run

if [[ ! -f deploy/akash.env ]]; then
  if [[ -f deploy/akash.env.example ]]; then
    cp deploy/akash.env.example deploy/akash.env
    log "created deploy/akash.env from example — edit AKASH_OWNER_ADDRESS + Vault creds"
  else
    log "WARN: deploy/akash.env.example missing"
  fi
else
  log "deploy/akash.env already exists"
fi

chmod +x scripts/start-mining.sh 2>/dev/null || true
chmod +x scripts/mining/start-termux.sh 2>/dev/null || true
chmod +x scripts/mining/stop-termux.sh 2>/dev/null || true
chmod +x scripts/deploy-to-akash.sh 2>/dev/null || true
chmod +x scripts/deploy-bittensor.sh 2>/dev/null || true

log "next steps:"
log "  1. nano deploy/akash.env   # set akash1... wallet + VAULT_* + BT_NETUID"
log "  2. ./scripts/start-mining.sh          # Akash Bittensor deploy"
log "  2b. ./scripts/mining/start-termux.sh # Termux local orchestrator (Grass/Helium)"
log "  docs: docs/MINING_QUICKSTART_TERMUX.md"
