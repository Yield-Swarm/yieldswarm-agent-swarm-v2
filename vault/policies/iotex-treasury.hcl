# Read IoTeX treasury + mining root secrets for Helix yield routing
path "secret/data/yieldswarm/iotex" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/treasury/mining_roots" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/iotex" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/treasury/mining_roots" {
  capabilities = ["read"]
}
