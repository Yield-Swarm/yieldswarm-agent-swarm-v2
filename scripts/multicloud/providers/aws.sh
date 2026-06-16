#!/usr/bin/env bash
# AWS provider — planned (deploy/multicloud/odysseus.yaml stub only).
set -euo pipefail

case "${1:-launch}" in
  launch)
    echo "AWS ECS GPU launch — planned (see deploy/multicloud/odysseus.yaml aws_ecs target)"
    echo "Store creds in Vault: kv/yieldswarm/cloud/aws"
    echo "[scaffold] workload=${WORKLOAD:-inference} — implement ECS task definition in future PR"
    exit 1
  ;;
  teardown)
    echo "AWS teardown — not yet implemented"
  ;;
  *) echo "usage: $0 [launch|teardown]"; exit 1 ;;
esac
