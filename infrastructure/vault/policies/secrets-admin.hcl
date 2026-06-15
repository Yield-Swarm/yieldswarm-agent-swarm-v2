# secrets-admin.hcl
# Full management of the YieldSwarm KV namespace, transit keys, and AppRoles.
# Intended for break-glass / seeding only - NOT for day-to-day workloads.

# KV v2 data + metadata (versioned).
path "secret/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "patch"]
}
path "secret/metadata/yieldswarm/*" {
  capabilities = ["list", "read", "delete"]
}
path "secret/delete/yieldswarm/*" {
  capabilities = ["update"]
}
path "secret/undelete/yieldswarm/*" {
  capabilities = ["update"]
}
path "secret/destroy/yieldswarm/*" {
  capabilities = ["update"]
}

# Transit (envelope encryption).
path "transit/keys/yieldswarm-*" {
  capabilities = ["create", "read", "update", "list"]
}
path "transit/keys/yieldswarm-*/rotate" {
  capabilities = ["update"]
}
path "transit/encrypt/yieldswarm-*" {
  capabilities = ["update"]
}
path "transit/decrypt/yieldswarm-*" {
  capabilities = ["update"]
}

# AppRole management for downstream roles only.
path "auth/approle/role/terraform-deployer" {
  capabilities = ["create", "read", "update"]
}
path "auth/approle/role/terraform-deployer/*" {
  capabilities = ["create", "read", "update"]
}
path "auth/approle/role/akash-workload" {
  capabilities = ["create", "read", "update"]
}
path "auth/approle/role/akash-workload/*" {
  capabilities = ["create", "read", "update"]
}

# Read-only visibility into self for diagnostics.
path "sys/capabilities-self" { capabilities = ["update"] }
path "sys/leases/lookup/*"   { capabilities = ["read", "update"] }
