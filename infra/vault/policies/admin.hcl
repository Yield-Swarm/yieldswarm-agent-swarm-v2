# =============================================================================
# Policy: admin
# -----------------------------------------------------------------------------
# Break-glass policy for the platform team. Attached to humans via OIDC (Azure
# AD / GitHub) and gated behind MFA + Sentinel EGP. Never attach to a service
# token or AppRole.
# =============================================================================

# Full control over secrets, auth, policies, mounts, audit devices.
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "patch"]
}

path "yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list", "patch"]
}

path "transit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "pki/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow tokens to look up themselves, renew themselves, revoke themselves.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
