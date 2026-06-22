#!/usr/bin/env bash
# scripts/devops/fork_ecosystem_sdks.sh
#
# Clone upstream SDK repositories into ./ecosystem-forks/, create a YieldSwarm
# migration branch, and drop integration hook stubs (YIELDSWARM_INTEGRATION.md).
#
# Does NOT push to remotes — operator sets origin and pushes per fork.
#
# Usage:
#   ./scripts/devops/fork_ecosystem_sdks.sh
#   ./scripts/devops/fork_ecosystem_sdks.sh --dry-run
#   MIGRATION_BRANCH=yieldswarm-migration-main ./scripts/devops/fork_ecosystem_sdks.sh
#   PATCH_PACKAGE_NAMES=1 ./scripts/devops/fork_ecosystem_sdks.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

WORKSPACE_DIR="${ECOSYSTEM_FORKS_DIR:-ecosystem-forks}"
LOG_FILE="${SDK_FORK_LOG:-.run/sdk_fork_alignment.log}"
MIGRATION_BRANCH="${MIGRATION_BRANCH:-yieldswarm-migration-$(git rev-parse --short HEAD 2>/dev/null || echo main)}"
PATCH_PACKAGE_NAMES="${PATCH_PACKAGE_NAMES:-0}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "${WORKSPACE_DIR}" .run

declare -A SDK_TARGETS=(
  ["cosmos-sdk"]="https://github.com/cosmos/cosmos-sdk"
  ["base-sdk"]="https://github.com/base-org/base"
  ["kraken-sdk"]="https://github.com/krakenfx/kraken-api-client"
  ["okx-sdk"]="https://github.com/okx/okx-wallet-sdk"
  ["uniswap-sdk"]="https://github.com/Uniswap/v3-sdk"
  ["aave-sdk"]="https://github.com/aave/aave-utilities"
  ["jupiter-sdk"]="https://github.com/jup-ag/jupiter-quote-api-node"
  ["meteora-sdk"]="https://github.com/MeteoraAg/dlmm-sdk"
  ["raydium-sdk"]="https://github.com/raydium-io/raydium-sdk"
  ["pump-fun-sdk"]="https://github.com/pump-fun/pump-ts"
  ["arbitrum-sdk"]="https://github.com/OffchainLabs/arbitrum-sdk"
  ["aptos-sdk"]="https://github.com/aptos-labs/aptos-ts-sdk"
  ["luna-sdk"]="https://github.com/terra-money/terra.js"
  ["zec-sdk"]="https://github.com/electric-coin-company/zcash"
  ["doge-sdk"]="https://github.com/rosetta-dogecoin/rosetta-dogecoin"
  ["ltc-sdk"]="https://github.com/litecoin-project/litecoin"
  ["kaspa-sdk"]="https://github.com/kaspanet/rusty-kaspa"
  ["tap-protocol-sdk"]="https://github.com/TransactionAuthorizationProtocol/tap-rs"
  ["near-sdk"]="https://github.com/near/near-api-js"
  ["pi-network-sdk"]="https://github.com/pi-apps/pi-platform-js-sdk"
  ["alchemy-sdk"]="https://github.com/alchemyplatform/alchemy-sdk-js"
  ["ethers-sdk"]="https://github.com/ethers-io/ethers.js"
)

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "${LOG_FILE}"
}

generate_yieldswarm_patch() {
  local name=$1
  cat <<EOF
/* YieldSwarm Matrix Overrides - Helix DNA v2.1 Integration */
const YIELDSWARM_ROUTING_CONFIG = {
  nexusGateway: "http://127.0.0.1:8080/api/nexus/route",
  helixYieldMatrix: "http://127.0.0.1:8080/api/helix/status",
  shadowZkObfuscator: "http://127.0.0.1:8080/api/shadow/status",
  rewardsStatus: "http://127.0.0.1:8080/api/rewards/status",
};
console.log("[${name} SDK fork] Rerouting execution paths through YieldSwarm sovereign pipelines.");
EOF
}

sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

log "INITIATING MULTI-CHAIN SDK FORK ENGINE (branch=${MIGRATION_BRANCH}, targets=${#SDK_TARGETS[@]})"

for sdk in "${!SDK_TARGETS[@]}"; do
  url="${SDK_TARGETS[$sdk]}"
  target_path="${WORKSPACE_DIR}/${sdk}"

  log "Processing: ${sdk} <- ${url}"

  if [[ "${DRY_RUN}" == 1 ]]; then
    log "  [dry-run] would clone/update ${target_path}"
    continue
  fi

  if [[ ! -d "${target_path}/.git" ]]; then
    git clone --depth=1 "${url}" "${target_path}" >>"${LOG_FILE}" 2>&1
  else
    log "  skip clone (exists): ${target_path}"
  fi

  (
    cd "${target_path}"
    git fetch --depth=1 origin 2>>"${LOG_FILE}" || true

    if git show-ref --verify --quiet "refs/heads/${MIGRATION_BRANCH}"; then
      git checkout "${MIGRATION_BRANCH}" >>"${LOG_FILE}" 2>&1
    else
      git checkout -b "${MIGRATION_BRANCH}" >>"${LOG_FILE}" 2>&1
    fi

    generate_yieldswarm_patch "${sdk}" > YIELDSWARM_INTEGRATION.md

    if [[ "${PATCH_PACKAGE_NAMES}" == 1 ]]; then
      if [[ -f package.json ]]; then
        sed_inplace 's/"name": "/&yieldswarm-fork-/g' package.json || true
      elif [[ -f Cargo.toml ]]; then
        sed_inplace 's/^name = "/&yieldswarm-fork-/g' Cargo.toml || true
      fi
    fi

    git add YIELDSWARM_INTEGRATION.md
    [[ "${PATCH_PACKAGE_NAMES}" == 1 ]] && git add package.json Cargo.toml 2>/dev/null || true

    if git diff --cached --quiet; then
      log "  no changes to commit for ${sdk}"
    else
      git commit -m "feat(yieldswarm): patch network pipelines to route via Tri-Solenoid matrix" \
        >>"${LOG_FILE}" 2>&1
    fi
  )

  log "OK ${sdk} -> branch ${MIGRATION_BRANCH}"
done

log "ALL SDK FORKS PROCESSED. Workspace: ${WORKSPACE_DIR}/"
log "Next: cd ecosystem-forks/<sdk> && git remote set-url origin <your-fork> && git push origin ${MIGRATION_BRANCH}"
