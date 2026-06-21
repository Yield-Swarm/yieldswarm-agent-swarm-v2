# =========================================================================
# shadow-runtime.hcl — Solenoid 3 Shadow Chain Arena (Kyle's chain)
# -------------------------------------------------------------------------
# Arena competition, reputation, reward distribution, ZK-Swarm Mutation batches.
# =========================================================================

path "yieldswarm/data/runtime/shadow" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/zk" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/backend" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/solana" {
  capabilities = ["read"]
}

path "transit/encrypt/shadow-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/shadow-runtime" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
