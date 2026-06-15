# =========================================================================
# bittensor-runtime.hcl — Akash Bittensor miner workload (Ollama + axon)
# =========================================================================

path "yieldswarm/data/runtime/bittensor" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/akash" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/bittensor" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
