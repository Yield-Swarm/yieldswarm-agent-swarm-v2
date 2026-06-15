# =============================================================================
# Vault Policy: admin
# YieldSwarm AgentSwarm OS v2.0
#
# Break-glass policy for human operators. Assign only to named individuals
# via tokens with short TTLs and require MFA enforcement.
# Never attach to automated systems.
# =============================================================================

# Full KV v2 access across all environments
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "patch"]
}

# Manage secrets engines, policies, and auth methods
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Enable/disable audit devices
path "sys/audit*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage AppRole credentials
path "auth/approle/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read cluster health and configuration
path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/leader" {
  capabilities = ["read"]
}

path "sys/replication/*" {
  capabilities = ["read", "list"]
}

# Token self-management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# Transit encryption (key management)
path "transit/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
