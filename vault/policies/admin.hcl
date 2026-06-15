# =========================================================================
# admin.hcl
# -------------------------------------------------------------------------
# Break-glass / platform-operator policy. Should only be attached to
# human identities authenticated through MFA-enforced OIDC, and to the
# initial root token used for bootstrap (which MUST be revoked after the
# Terraform Vault-config run succeeds).
# =========================================================================

# Manage every secret engine, auth method, policy, and token under sys/
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read/write everything in our KV mounts
path "yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list", "patch"]
}

path "yieldswarm/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage AppRoles and other auth backends
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Transit (envelope encryption for at-rest secrets in apps)
path "transit/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# PKI for internal mTLS
path "pki/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Identity store (entities, groups, aliases)
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow listing and inspecting token leases for incident response
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
