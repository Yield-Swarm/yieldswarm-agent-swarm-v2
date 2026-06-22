#!/usr/bin/env bash
# One-command Bittensor miner spin-up on Akash (Azure Cloud Shell / Termux / laptop).
#
# Usage:
#   cd ~/yieldswarm-agent-swarm-v2
#   cp deploy/akash.env.example deploy/akash.env   # first time only
#   nano deploy/akash.env                          # set wallet + Vault
#   ./scripts/start-mining.sh
#
# Env:
#   MINING_SDL=deploy/akash-bittensor-miner.sdl.yml
#   USE_VAULT_AKASH=1  → routes through deploy-bittensor.sh (recommended)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

echo "=== YIELDSWARM MINING SPIN-UP ==="
echo "repo: ${REPO_ROOT}"

# Load operator env (gitignored)
for f in deploy/akash.env deploy/config.env .env; do
  if [[ -f "$f" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
    echo "loaded ${f}"
    break
  fi
done

export AKASH_KEY_NAME="${AKASH_KEY_NAME:-yieldswarm}"
export AUTO_SELECT_BID="${AUTO_SELECT_BID:-1}"
export BT_NETUID="${BT_NETUID:-1}"
export BT_NETWORK="${BT_NETWORK:-finney}"
export BT_WALLET_NAME="${BT_WALLET_NAME:-miner}"
export BT_HOTKEY_NAME="${BT_HOTKEY_NAME:-default}"

MINING_SDL="${MINING_SDL:-deploy/akash-bittensor-miner.sdl.yml}"
DEPLOY_SDL="${DEPLOY_SDL:-${MINING_SDL}}"

if ! command -v provider-services >/dev/null 2>&1 && ! command -v akash >/dev/null 2>&1; then
  echo "WARN: Akash CLI not found."
  echo "  Install: https://akash.network/docs/deployments/akash-cli/install"
  echo "  Or on Termux: see docs/MINING_QUICKSTART_TERMUX.md"
fi

if [[ -x "${SCRIPT_DIR}/akash-preflight.sh" ]]; then
  echo "Preflight..."
  "${SCRIPT_DIR}/akash-preflight.sh" || echo "WARN: preflight NO-GO — fix wallet/Vault and retry"
fi

# Preferred: Vault-wrapped Bittensor deploy
if [[ "${USE_VAULT_AKASH:-1}" == "1" && -x "${SCRIPT_DIR}/deploy-bittensor.sh" ]]; then
  if [[ -n "${VAULT_ADDR:-}" ]] && [[ -n "${VAULT_TOKEN:-}${VAULT_ROLE_ID:-}" ]]; then
    echo "Deploying via deploy-bittensor.sh (Vault injection)..."
    exec "${SCRIPT_DIR}/deploy-bittensor.sh"
  fi
  echo "Vault not configured — falling back to direct SDL deploy"
fi

if [[ ! -f "${DEPLOY_SDL}" ]]; then
  echo "ERROR: SDL not found: ${DEPLOY_SDL}" >&2
  exit 1
fi

echo "Deploying SDL: ${DEPLOY_SDL}"
if [[ -x "${SCRIPT_DIR}/deploy-to-akash.sh" ]]; then
  exec "${SCRIPT_DIR}/deploy-to-akash.sh" deploy "${DEPLOY_SDL}"
fi

if [[ -x "${SCRIPT_DIR}/akash-deploy.sh" ]]; then
  exec "${SCRIPT_DIR}/akash-deploy.sh" "${DEPLOY_SDL}"
fi

echo "ERROR: no deploy script found (deploy-to-akash.sh or akash-deploy.sh)" >&2
exit 1
