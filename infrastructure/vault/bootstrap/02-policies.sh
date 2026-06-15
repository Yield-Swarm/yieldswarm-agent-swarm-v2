#!/usr/bin/env bash
# 02-policies.sh
# Apply YieldSwarm Vault ACL policies.

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

vault_status_or_die

log "Applying policies from $POLICY_DIR"
policy_write secrets-admin       "$POLICY_DIR/secrets-admin.hcl"
policy_write terraform-deployer  "$POLICY_DIR/terraform-deployer.hcl"
policy_write akash-workload      "$POLICY_DIR/akash-workload.hcl"
policy_write ci-pipeline         "$POLICY_DIR/ci-pipeline.hcl"

ok "policies applied"
