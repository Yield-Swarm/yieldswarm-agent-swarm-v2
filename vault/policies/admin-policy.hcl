# Break-glass admin policy — assign only to human operators with MFA.
# Rotate root token after bootstrap; use this policy for day-2 operations.

path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/create" {
  capabilities = ["create", "update"]
}

path "yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "yieldswarm/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "sys/health" {
  capabilities = ["read", "sudo"]
}
