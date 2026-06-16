#!/usr/bin/env bash
# Alibaba Cloud provider — planned filler capacity.
set -euo pipefail

case "${1:-launch}" in
  launch)
    echo "Alibaba ECS launch — planned (Asia-region filler)"
    echo "Store creds in Vault: kv/yieldswarm/cloud/alibaba"
    echo "[scaffold] workload=${WORKLOAD:-cpu-batch}"
    exit 1
  ;;
  teardown)
    echo "Alibaba teardown — not yet implemented"
  ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac
