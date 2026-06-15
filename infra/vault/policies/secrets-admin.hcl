# =============================================================================
# Policy: secrets-admin
# For human operators / the platform team. Full lifecycle management of the
# YieldSwarm secret tree plus the auth methods and policies that back it.
# Assign via an identity group mapped to your SSO (OIDC) — do NOT hand out
# the root token. Root should be revoked after bootstrap.
# =============================================================================

# Full management of the KV v2 secret tree.
path "kv/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
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

# Manage the secrets engines themselves.
path "sys/mounts" {
  capabilities = ["read", "list"]
}
path "sys/mounts/kv" {
  capabilities = ["create", "read", "update", "delete"]
}

# Manage the AppRole auth method and its roles.
path "auth/approle/role/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/auth" {
  capabilities = ["read", "list"]
}

# Manage ACL policies.
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read audit + health for operational visibility.
path "sys/audit" {
  capabilities = ["read", "list", "sudo"]
}
path "sys/health" {
  capabilities = ["read"]
}
