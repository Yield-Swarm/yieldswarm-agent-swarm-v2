# Full administrative access for bootstrap and break-glass only.
# Bind to human operators via OIDC or tightly scoped tokens.

path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "yieldswarm/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
