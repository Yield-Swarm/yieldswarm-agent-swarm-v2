# ============================================================
# Policy: yieldswarm-admin
# Scope : Full lifecycle control over all YieldSwarm secret
#         paths, policy management, and auth configuration.
#         Bind ONLY to break-glass operator tokens — never to
#         automated workloads.
# ============================================================

# All KV v2 secret data under the yieldswarm namespace
path "secret/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/delete/yieldswarm/*" {
  capabilities = ["update"]
}

path "secret/undelete/yieldswarm/*" {
  capabilities = ["update"]
}

path "secret/destroy/yieldswarm/*" {
  capabilities = ["update"]
}

path "secret/config" {
  capabilities = ["read"]
}

# Policy CRUD
path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete"]
}

# Auth method management (read existing, manage approle roles)
path "sys/auth" {
  capabilities = ["read"]
}

path "sys/auth/approle" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

path "auth/approle/role/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/yieldswarm-*/secret-id" {
  capabilities = ["update"]
}

path "auth/approle/role/yieldswarm-*/secret-id/lookup" {
  capabilities = ["update"]
}

path "auth/approle/role/yieldswarm-*/secret-id/destroy" {
  capabilities = ["update"]
}

# Secrets engine mounts
path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/mounts/secret" {
  capabilities = ["create", "read", "update"]
}

# Audit log management
path "sys/audit" {
  capabilities = ["read", "list"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# Token management for issuing child tokens
path "auth/token/create" {
  capabilities = ["create", "update"]
}

path "auth/token/create-orphan" {
  capabilities = ["create", "update", "sudo"]
}

path "auth/token/lookup" {
  capabilities = ["update"]
}

path "auth/token/revoke" {
  capabilities = ["update"]
}

path "auth/token/renew" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Seal/health inspection (read-only)
path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/seal-status" {
  capabilities = ["read"]
}
