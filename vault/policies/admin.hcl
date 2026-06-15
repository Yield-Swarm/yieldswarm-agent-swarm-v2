# Full administrative access to YieldSwarm secret paths.
# Bind only to break-glass OIDC/group principals or initial bootstrap token.
# Rotate bootstrap token immediately after policy/AppRole setup.

path "sys/mounts/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "yieldswarm/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "yieldswarm/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "yieldswarm/delete/*" {
  capabilities = ["update"]
}

path "yieldswarm/undelete/*" {
  capabilities = ["update"]
}

path "yieldswarm/destroy/*" {
  capabilities = ["update"]
}

path "auth/approle/role/yieldswarm-terraform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/yieldswarm-akash-runtime/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
