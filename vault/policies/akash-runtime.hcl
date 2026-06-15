# Akash-hosted workloads read runtime configuration from KV v2. They never
# receive permission to list, write, delete, or manage Vault itself.
path "secret/data/yieldswarm/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/llm" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/runpod" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/vultr" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/depin/akash" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/blockchain/signing" {
  capabilities = ["read"]
}

path "transit/encrypt/yieldswarm-wallet" {
  capabilities = ["update"]
}

path "transit/decrypt/yieldswarm-wallet" {
  capabilities = ["update"]
}
