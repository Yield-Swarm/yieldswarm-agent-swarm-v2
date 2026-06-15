## admin policy - break-glass only.  Issue via short-lived (1h) token,
## audited, and require two-person approval workflow externally.

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
