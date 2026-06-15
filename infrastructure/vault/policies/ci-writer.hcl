# =============================================================================
# Policy: ci-writer
# Purpose: Allows CI/CD (GitHub Actions OIDC -> Vault JWT auth) to push new
#          secret versions but NEVER read existing values. This is the
#          "secret seeding" lane used when rotating cloud-provider keys.
# =============================================================================

path "kv/data/yieldswarm/infra/*" {
  capabilities = ["create", "update"]
}

path "kv/data/yieldswarm/rpc" {
  capabilities = ["create", "update"]
}

path "kv/metadata/yieldswarm/*" {
  capabilities = ["read", "list"]
}

# Explicitly deny reads of the data path so a compromised CI token cannot
# exfiltrate the values it just wrote.
path "kv/data/yieldswarm/runtime/*" {
  capabilities = ["deny"]
}
