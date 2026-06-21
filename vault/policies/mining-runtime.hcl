# Read mining fleet secrets + runtime auth material
path "secret/data/yieldswarm/mining/wallets" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/runtime/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/runtime/bittensor" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/runtime/wallets" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/runtime/akash" {
  capabilities = ["read"]
}
