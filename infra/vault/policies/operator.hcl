## operator policy - day-to-day humans managing app secrets.
## No mount/auth/system mutation, no token wrapping bypass.

path "kv/data/yieldswarm/*" {
  capabilities = ["create", "read", "update", "delete", "patch"]
}

path "kv/metadata/yieldswarm/*" {
  capabilities = ["list", "read", "delete"]
}

path "kv/delete/yieldswarm/*"   { capabilities = ["update"] }
path "kv/undelete/yieldswarm/*" { capabilities = ["update"] }
path "kv/destroy/yieldswarm/*"  { capabilities = ["update"] }

path "transit/encrypt/+" { capabilities = ["update"] }
path "transit/decrypt/+" { capabilities = ["update"] }
path "transit/sign/+"    { capabilities = ["update"] }
path "transit/verify/+"  { capabilities = ["update"] }

path "sys/capabilities-self" { capabilities = ["update"] }
path "sys/leases/lookup"     { capabilities = ["update"] }
path "sys/leases/renew"      { capabilities = ["update"] }
