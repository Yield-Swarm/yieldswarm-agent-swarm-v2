# Multicloud operator — Beefcake, burst scripts, terraform operators.
# Read cloud provider creds + Akash deploy metadata. No runtime agent shards.

path "yieldswarm/data/cloud/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/providers/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/akash/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/integrations/tesla" {
  capabilities = ["read"]
}
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/cloud/*" {
  capabilities = ["read", "list"]
}
path "yieldswarm/metadata/providers/*" {
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

# Deny agent shard keys and payment hot wallets on ops hosts
path "yieldswarm/data/agents/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/payments/web3" {
  capabilities = ["deny"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
