# =============================================================================
# Policy: secrets-rotator
# -----------------------------------------------------------------------------
# Granted to the rotation cron (one of the 120 cron jobs). Allowed to WRITE
# new versions of provider credentials and delete old ones, but cannot read
# their current values back from anywhere else. The rotator's flow:
#
#   1. Mint new credential at the provider via that provider's API.
#   2. Write the new credential to yieldswarm/data/infra/<provider>.
#   3. Bump the KV-v2 version metadata.
#   4. Revoke the previous credential at the provider AFTER N minutes once
#      Vault Agent rendering has propagated everywhere.
# =============================================================================

path "yieldswarm/data/infra/*" {
  capabilities = ["create", "update", "patch"]
}

path "yieldswarm/metadata/infra/*" {
  capabilities = ["read", "list", "update", "delete"]
}

path "yieldswarm/data/rpc/*" {
  capabilities = ["create", "update", "patch"]
}

path "yieldswarm/metadata/rpc/*" {
  capabilities = ["read", "list", "update", "delete"]
}

# Rotator must look up its own token + renew + revoke on shutdown.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
