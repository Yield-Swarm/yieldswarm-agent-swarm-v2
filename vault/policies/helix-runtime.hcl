# =========================================================================
# helix-runtime.hcl — Solenoid 2 Helix Reverberator
# -------------------------------------------------------------------------
# Cross-chain treasury routing, bridge keys, ZK-Swarm verifier config.
# =========================================================================

path "yieldswarm/data/runtime/helix" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/wallets" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/zk" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/solana" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/ethereum" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/kairo" {
  capabilities = ["read"]
}

path "transit/encrypt/helix-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/helix-runtime" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
