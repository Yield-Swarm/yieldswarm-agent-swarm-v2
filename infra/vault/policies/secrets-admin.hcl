# Policy: secrets-admin
# Grants an operator the ability to manage (create/update/read/delete) the
# YieldSwarm secret tree and rotate AppRole SecretIDs. This is intended for
# the human/CI principal that runs bootstrap.sh and seed-secrets.sh.
#
# The KV mount name is templated with the placeholder @@KV_MOUNT@@ and is
# substituted by infra/vault/bootstrap.sh at apply time (default: "secret").
#
# This policy deliberately does NOT include "sudo" or root capabilities and is
# scoped exclusively to the yieldswarm/ secret subtree and its AppRoles.

# Full management of the YieldSwarm KV data and metadata.
path "@@KV_MOUNT@@/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}

path "@@KV_MOUNT@@/metadata/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage the AppRole auth roles used by Terraform and the Akash runtime.
path "auth/approle/role/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read RoleIDs and generate/rotate SecretIDs for those roles.
path "auth/approle/role/yieldswarm-*/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/yieldswarm-*/secret-id" {
  capabilities = ["create", "update"]
}

path "auth/approle/role/yieldswarm-*/secret-id/*" {
  capabilities = ["create", "update", "delete"]
}
