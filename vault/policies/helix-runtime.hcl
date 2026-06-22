# =========================================================================
# helix-runtime.hcl — Solenoid 2 (Helix Reverberator) cross-chain yield
# -------------------------------------------------------------------------
# Granted to Helix relayers, bridge workers, and IoTeX treasury routers.
# Reads mining roots, IoTeX hub, wallet signing keys, and RPC endpoints.
# =========================================================================

path "yieldswarm/data/treasury/manifest" {
  capabilities = ["read"]
}
path "yieldswarm/data/treasury/mining_roots" {
  capabilities = ["read"]
}
path "yieldswarm/data/iotex/hub" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/helix" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/rpc/ethereum" {
  capabilities = ["read"]
}
path "yieldswarm/data/rpc/solana" {
  capabilities = ["read"]
}

path "transit/encrypt/agent-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/agent-runtime" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Helix must not read cloud provider root creds
path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
