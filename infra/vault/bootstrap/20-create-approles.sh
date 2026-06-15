#!/usr/bin/env bash
# Create the AppRoles consumed by Terraform and the Akash runtime.
#
# After running this script, fetch the role-id and an initial secret-id
# with the helper printed at the end and inject them into the consuming
# system (Terraform CI, Akash deployment env). Never check these values
# into git.

set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

log() { printf '[bootstrap] %s\n' "$*"; }

# ----- Terraform role -----------------------------------------------------
# Short TTL, bound to CIDR ranges that match the CI runners. Override
# APN_TERRAFORM_CIDRS with a comma-separated list of CIDRs for your CI
# fleet (e.g. "10.10.0.0/24,10.10.1.0/24").
TF_CIDRS="${APN_TERRAFORM_CIDRS:-0.0.0.0/0}"

log "creating AppRole apn-terraform"
vault write auth/approle/role/apn-terraform \
  token_policies="apn-terraform-read" \
  token_ttl="20m" \
  token_max_ttl="1h" \
  token_num_uses=0 \
  secret_id_ttl="24h" \
  secret_id_num_uses=20 \
  bind_secret_id=true \
  token_bound_cidrs="${TF_CIDRS}" \
  secret_id_bound_cidrs="${TF_CIDRS}"

# ----- Akash runtime role -------------------------------------------------
# Longer-lived secret-id (rotated by the Vault Agent on the host), short
# token TTL so any leaked token expires quickly. Bound to the egress
# CIDRs of the Akash providers we deploy to.
AKASH_CIDRS="${APN_AKASH_CIDRS:-0.0.0.0/0}"

log "creating AppRole apn-akash-runtime"
vault write auth/approle/role/apn-akash-runtime \
  token_policies="apn-akash-runtime" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  token_num_uses=0 \
  secret_id_ttl="720h" \
  secret_id_num_uses=0 \
  bind_secret_id=true \
  token_bound_cidrs="${AKASH_CIDRS}" \
  secret_id_bound_cidrs="${AKASH_CIDRS}"

# ----- Transit keys ------------------------------------------------------
# Create the encryption and signing keys used by the runtime policy.
# `derived=true` lets us scope encryption to a per-tenant context.
for key in apn-wallet-encryption apn-db-encryption; do
  if vault read -format=json "transit/keys/${key}" >/dev/null 2>&1; then
    log "transit key ${key} already exists"
  else
    log "creating transit key ${key}"
    vault write -f "transit/keys/${key}" type=aes256-gcm96 derived=true
  fi
done

if vault read -format=json transit/keys/apn-tee-signing >/dev/null 2>&1; then
  log "transit key apn-tee-signing already exists"
else
  log "creating transit signing key apn-tee-signing"
  vault write -f transit/keys/apn-tee-signing type=ed25519
fi

cat <<EOF

AppRoles created. To fetch credentials for delivery into CI / Akash:

  vault read -format=json auth/approle/role/apn-terraform/role-id \\
    | jq -r .data.role_id

  vault write -f -format=json auth/approle/role/apn-terraform/secret-id \\
    | jq -r .data.secret_id

  vault read -format=json auth/approle/role/apn-akash-runtime/role-id \\
    | jq -r .data.role_id

  vault write -f -wrap-ttl=5m -format=json \\
    auth/approle/role/apn-akash-runtime/secret-id \\
    | jq -r .wrap_info.token

Wrap the akash secret-id so the operator who configures the deployment
is the only party that ever sees the raw value (single-use unwrap).
EOF
