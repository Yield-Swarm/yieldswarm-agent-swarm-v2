# Treasury manifest read access for Helix / cross-chain services

path "yieldswarm/data/treasury/manifest" {
  capabilities = ["read"]
}

path "yieldswarm/data/treasury/mining_roots" {
  capabilities = ["read"]
}

path "yieldswarm/data/iotex/hub" {
  capabilities = ["read"]
}

path "yieldswarm/data/iotex/api" {
  capabilities = ["read"]
}
