#!/usr/bin/env bash
set -euo pipefail

# Deploys and verifies GreatDeltaEmissionRouter using Foundry tooling.
# Required env vars:
#   RPC_URL
#   PRIVATE_KEY
#   ETHERSCAN_API_KEY
#   CHAIN_ID
#   REWARD_TOKEN
#   MULTISIG_50
#   MULTISIG_30
#   MULTISIG_15
#   MULTISIG_05
#   BASE_REWARD_PER_BLOCK
#   MIN_REWARD_PER_BLOCK
#   MAX_REWARD_PER_BLOCK
#   PROJECTED_STAKE_BASE
#   BLOCKS_PER_YEAR
#
# Optional env vars:
#   START_BLOCK (defaults to current block number)

required_vars=(
  RPC_URL
  PRIVATE_KEY
  ETHERSCAN_API_KEY
  CHAIN_ID
  REWARD_TOKEN
  MULTISIG_50
  MULTISIG_30
  MULTISIG_15
  MULTISIG_05
  BASE_REWARD_PER_BLOCK
  MIN_REWARD_PER_BLOCK
  MAX_REWARD_PER_BLOCK
  PROJECTED_STAKE_BASE
  BLOCKS_PER_YEAR
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required env var: ${var_name}" >&2
    exit 1
  fi
done

if [[ -z "${START_BLOCK:-}" ]]; then
  START_BLOCK="$(cast block-number --rpc-url "${RPC_URL}")"
fi

constructor_args="$(cast abi-encode \
  "constructor(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256)" \
  "${REWARD_TOKEN}" \
  "${MULTISIG_50}" \
  "${MULTISIG_30}" \
  "${MULTISIG_15}" \
  "${MULTISIG_05}" \
  "${BASE_REWARD_PER_BLOCK}" \
  "${MIN_REWARD_PER_BLOCK}" \
  "${MAX_REWARD_PER_BLOCK}" \
  "${PROJECTED_STAKE_BASE}" \
  "${BLOCKS_PER_YEAR}" \
  "${START_BLOCK}")"

echo "Deploying GreatDeltaEmissionRouter..."
deploy_output="$(
  forge create \
    --rpc-url "${RPC_URL}" \
    --private-key "${PRIVATE_KEY}" \
    --etherscan-api-key "${ETHERSCAN_API_KEY}" \
    --chain-id "${CHAIN_ID}" \
    --constructor-args "${constructor_args}" \
    --verify \
    contracts/GreatDeltaEmissionRouter.sol:GreatDeltaEmissionRouter
)"

echo "${deploy_output}"

contract_address="$(echo "${deploy_output}" | rg "Deployed to:" | awk '{print $3}')"
if [[ -z "${contract_address}" ]]; then
  echo "Could not parse deployed contract address from forge output." >&2
  exit 1
fi

echo "Deployment complete: ${contract_address}"
echo "Verification request submitted via forge --verify."
