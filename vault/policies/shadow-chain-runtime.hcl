# =========================================================================
# shadow-chain-runtime.hcl — Solenoid 3 (Shadow Chain / Arena)
# -------------------------------------------------------------------------
# Granted to Arena API, Kyle's chain validators, and ZK-Swarm mutation workers.
# Reads backend runtime, ZK verifier config, and agent shard telemetry.
# =========================================================================

path "yieldswarm/data/runtime/backend" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/shadow" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/zk" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}

path "yieldswarm/data/agents/shards/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/integrations/+" {
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

# Arena workloads must not access cloud operator creds or hot wallets
path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
path "yieldswarm/data/payments/web3" {
  capabilities = ["deny"]
}
