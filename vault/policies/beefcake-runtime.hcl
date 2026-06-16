# Beefcake 1 AWS worker — sovereign loops, multicloud launch, telemetry.
# Narrower than multicloud-operator: no payment rails or agent shard keys.

path "yieldswarm/data/cloud/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/providers/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/akash/wallet" {
  capabilities = ["read"]
}
path "yieldswarm/data/akash/deployment" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/akash" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}
path "yieldswarm/data/internal/redis" {
  capabilities = ["read"]
}
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/cloud/*" {
  capabilities = ["read", "list"]
}
path "yieldswarm/metadata/akash/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/payments/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/agents/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
