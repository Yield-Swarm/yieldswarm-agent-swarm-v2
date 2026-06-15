#!/usr/bin/env bash
# vault/setup/bootstrap.sh
#
# End-to-end orchestrator that runs the 5 setup steps in order. Designed
# to be run ONCE on a fresh Vault from a trusted operator workstation.
#
# Usage:
#   VAULT_ADDR=https://vault.yieldswarm.io:8200 \
#   OUTPUT_DIR=./.vault-init \
#   SOURCE_ENV=./.env \
#   ./vault/setup/bootstrap.sh
#
# After it returns successfully:
#   1. Distribute the 5 unseal shares from $OUTPUT_DIR/init.json to holders.
#   2. Shred $OUTPUT_DIR/init.json (`shred -u`) on this host.
#   3. Revoke the root token used for this run (vault token revoke <root>).
#   4. Switch to OIDC for any further human admin work.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${HERE}/01-init.sh"

# 01-init.sh exports VAULT_TOKEN from init.json if it wasn't already set.
export VAULT_TOKEN="${VAULT_TOKEN:-$(jq -r '.root_token' "${OUTPUT_DIR:-./.vault-init}/init.json")}"

"${HERE}/02-enable-engines.sh"
"${HERE}/03-write-policies.sh"
"${HERE}/04-enable-auth.sh"

if [ -n "${SOURCE_ENV:-}" ] && [ -r "${SOURCE_ENV}" ]; then
  "${HERE}/05-seed-secrets.sh"
else
  printf '\n[bootstrap] SOURCE_ENV not provided; skipping secret seeding.\n'
fi

cat <<EOF

============================================================
Vault bootstrap complete.

Next steps (DO THESE NOW):
  1. Distribute unseal shares from ${OUTPUT_DIR:-./.vault-init}/init.json
     to the 5 holders, then:
        shred -u ${OUTPUT_DIR:-./.vault-init}/init.json
  2. Revoke the root token:
        vault token revoke "\${VAULT_TOKEN}"
  3. Future admin access: \`vault login -method=oidc\` (if enabled)
  4. Run \`terraform init && terraform apply\` in vault/terraform-vault-config
     to bring the server config under GitOps management.
============================================================
EOF
