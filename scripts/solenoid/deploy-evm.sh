#!/usr/bin/env bash
# Deploy Phase 2 Solenoid EVM contracts (local Anvil or RPC via DEPLOYER_RPC).
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"

export PATH="${HOME}/.foundry/bin:${PATH}"
: "${DEPLOYER_RPC:=http://127.0.0.1:8545}"
: "${GOVERNANCE_COUNCIL:?set GOVERNANCE_COUNCIL address}"
: "${ASSET_VAULT:?set ASSET_VAULT address}"

log() { printf '[solenoid-deploy] %s\n' "$*" >&2; }

if ! command -v forge >/dev/null; then
  log "install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
  exit 1
fi

FOUNDRY_PROFILE=solenoid forge build >/dev/null
log "rpc=${DEPLOYER_RPC}"

NEXUS=$(forge create contracts/solenoid/Nexus.sol:Nexus \
  --rpc-url "${DEPLOYER_RPC}" \
  --constructor-args "${GOVERNANCE_COUNCIL}" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['deployedTo'])")

HELIX=$(forge create contracts/solenoid/Helix.sol:Helix \
  --rpc-url "${DEPLOYER_RPC}" \
  --constructor-args "${NEXUS}" "${ASSET_VAULT}" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['deployedTo'])")

SHADOW=$(forge create contracts/solenoid/Shadow.sol:Shadow \
  --rpc-url "${DEPLOYER_RPC}" \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)['deployedTo'])")

log "Nexus=${NEXUS}"
log "Helix=${HELIX}"
log "Shadow=${SHADOW}"
log "Next: council.setCallerStatus(${HELIX}, true) on Nexus"

printf '{"nexus":"%s","helix":"%s","shadow":"%s"}\n' "${NEXUS}" "${HELIX}" "${SHADOW}"
