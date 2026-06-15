# =============================================================================
# Policy: secrets-admin
# Purpose: Human / break-glass operator policy. Allows full CRUD on the
#          yieldswarm KV namespace + transit key admin. Should be bound to
#          userpass / OIDC users with hardware MFA enforced via sentinel.
# =============================================================================

path "kv/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "patch"]
}

path "kv/metadata/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv/delete/yieldswarm/*" {
  capabilities = ["update"]
}

path "kv/undelete/yieldswarm/*" {
  capabilities = ["update"]
}

path "kv/destroy/yieldswarm/*" {
  capabilities = ["update"]
}

# Transit keys
path "transit/keys/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "transit/keys/yieldswarm-*/rotate" {
  capabilities = ["update"]
}

# AppRole management
path "auth/approle/role/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/yieldswarm-*/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/yieldswarm-*/secret-id" {
  capabilities = ["create", "update"]
}

# Wrap / unwrap for handing secret_ids to CI/CD or operators
path "sys/wrapping/wrap" {
  capabilities = ["update"]
}

path "sys/wrapping/unwrap" {
  capabilities = ["update"]
}

path "sys/wrapping/lookup" {
  capabilities = ["update"]
}
