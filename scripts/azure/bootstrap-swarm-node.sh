#!/usr/bin/env bash
# One-shot Azure swarm node bootstrap (run ON the VM after SSH).
set -euo pipefail

SWARM_NODE_ID="${SWARM_NODE_ID:-9}"
BRANCH="${SWARM_BRANCH:-cursor/open-metal-inference-93dd}"
REPO_URL="${SWARM_REPO_URL:-https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git}"

sudo apt-get update -y
sudo apt-get install -y curl git

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

cd "$HOME"
rm -rf yieldswarm-agent-swarm-v2
git clone "${REPO_URL}" yieldswarm-agent-swarm-v2
cd yieldswarm-agent-swarm-v2
git checkout "${BRANCH}"

export SWARM_NODE_ID
export RPC_URL="${RPC_URL:-https://localhost:8545}"
export API_KEY="${API_KEY:-default_swarm_key}"
export NODE_ENV=production

./scripts/swarm/remediate-node-env.sh
npm run swarm:mainnet
