#!/usr/bin/env bash
# Deploy YieldSwarm Anchor programs to localnet | devnet | mainnet-beta
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${1:-devnet}"

cd "$ROOT"
case "$CLUSTER" in
  localnet) anchor build && anchor deploy ;;
  devnet)   anchor build && anchor deploy --provider.cluster devnet ;;
  mainnet-beta|mainnet) anchor build && anchor deploy --provider.cluster mainnet ;;
  *) echo "usage: $0 [localnet|devnet|mainnet-beta]" >&2; exit 1 ;;
esac
echo "Deployed to $CLUSTER"
