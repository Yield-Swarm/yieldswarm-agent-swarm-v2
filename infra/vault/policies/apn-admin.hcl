# apn-admin: break-glass policy for human operators and CI bootstrap.
#
# Scope:
#   - Full management of the apn KV tree, the transit keys we use for
#     wallet / TEE / DB envelope encryption, and the auth methods that
#     issue tokens to Terraform and Akash workloads.
#   - System-level paths are scoped tightly so an apn-admin token cannot
#     reconfigure unrelated mounts elsewhere in the Vault cluster.
#
# Do NOT bind this policy to a long-lived token. Issue it via a short
# -ttl, response-wrapped admin token (see docs/SECRETS.md).

# Full lifecycle on the apn KV v2 tree.
path "kv/data/apn/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "kv/metadata/apn/*" {
  capabilities = ["read", "list", "delete"]
}

path "kv/delete/apn/*" {
  capabilities = ["update"]
}

path "kv/undelete/apn/*" {
  capabilities = ["update"]
}

path "kv/destroy/apn/*" {
  capabilities = ["update"]
}

# Transit keys: create, rotate, configure (but never export plaintext).
path "transit/keys/apn-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "transit/keys/apn-*/config" {
  capabilities = ["update"]
}

path "transit/keys/apn-*/rotate" {
  capabilities = ["update"]
}

# AppRole administration scoped to the apn-* roles.
path "auth/approle/role/apn-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/apn-*/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/apn-*/secret-id" {
  capabilities = ["create", "update", "read"]
}

path "auth/approle/role/apn-*/secret-id/*" {
  capabilities = ["read", "delete"]
}

# Policy management is scoped to apn-* policies.
path "sys/policies/acl/apn-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl" {
  capabilities = ["list"]
}

# Mount management is scoped to the engines we actually use.
path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/mounts/kv" {
  capabilities = ["create", "read", "update"]
}

path "sys/mounts/transit" {
  capabilities = ["create", "read", "update"]
}

path "sys/auth" {
  capabilities = ["read"]
}

path "sys/auth/approle" {
  capabilities = ["create", "read", "update"]
}

# Health / leader / capability self-inspection.
path "sys/health" {
  capabilities = ["read"]
}

path "sys/leader" {
  capabilities = ["read"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
