#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   export DEPLOYER_PRIVATE_KEY=...
#   export RPC_URL=...
#   export GD_SIGNER_0=0x...
#   export GD_SIGNER_1=0x...
#   export GD_SIGNER_2=0x...
#   export GD_TREASURY_CORE=0x...
#   export GD_TREASURY_GROWTH=0x...
#   export GD_TREASURY_INSURANCE=0x...
#   export GD_TREASURY_OPS=0x...
#   export GD_BASE_EMISSION_WEI=1000000000000000000
#   export GD_MIN_POW_BPS=8500
#   export GD_MAX_POW_BPS=12500
#   export GD_MIN_CELESTIAL_BPS=9000
#   export GD_MAX_CELESTIAL_BPS=12000
#   export GD_MANDELBROT_ITERATIONS=48
#   export GD_SEED_RESERVE_WEI=0 # optional
#   ./scripts/deploy_great_delta_router.sh

required_vars=(
  DEPLOYER_PRIVATE_KEY
  RPC_URL
  GD_SIGNER_0
  GD_SIGNER_1
  GD_SIGNER_2
  GD_TREASURY_CORE
  GD_TREASURY_GROWTH
  GD_TREASURY_INSURANCE
  GD_TREASURY_OPS
  GD_BASE_EMISSION_WEI
  GD_MIN_POW_BPS
  GD_MAX_POW_BPS
  GD_MIN_CELESTIAL_BPS
  GD_MAX_CELESTIAL_BPS
  GD_MANDELBROT_ITERATIONS
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required env var: ${var_name}" >&2
    exit 1
  fi
done

if ! command -v forge >/dev/null 2>&1; then
  echo "forge not found. Install Foundry first: https://book.getfoundry.sh/getting-started/installation" >&2
  exit 1
fi

forge script scripts/DeployGreatDeltaEmissionRouter.s.sol:DeployGreatDeltaEmissionRouter \
  --rpc-url "${RPC_URL}" \
  --broadcast \
  -vvvv
