#!/usr/bin/env bash
# 00-bootstrap.sh
# Single entry-point that runs the full Vault bootstrap pipeline in order.
# All sub-scripts are idempotent.

set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

log "Running full YieldSwarm Vault bootstrap"
"$SCRIPT_DIR/01-engines.sh"
"$SCRIPT_DIR/02-policies.sh"
"$SCRIPT_DIR/03-approles.sh"
ok "bootstrap complete"

cat >&2 <<EOF

Next steps:
  1. Seed real secrets (interactively, NEVER in shell history):
       VAULT_TOKEN=<admin> infrastructure/vault/seed/seed-secrets.sh
  2. Export role_id & wrapped secret_id to your CI runner / Akash provider.
  3. Tighten TERRAFORM_CIDR / AKASH_CIDR and re-run 03-approles.sh.
  4. Read infrastructure/vault/README.md and SECRETS.md before going live.
EOF
