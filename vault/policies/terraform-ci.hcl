# Terraform automation configures Vault and reads only the deployment secrets
# required to configure downstream cloud providers.
path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth" {
  capabilities = ["read"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/yieldswarm-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/yieldswarm-*/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/yieldswarm-*/secret-id" {
  capabilities = ["create", "update"]
}

path "secret/data/yieldswarm/cloud/*" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/*" {
  capabilities = ["list", "read"]
}

path "transit/keys/yieldswarm-*" {
  capabilities = ["create", "read", "update", "list"]
}
