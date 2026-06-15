# akash-workload.hcl
# Granted to long-running containers on Akash. Read-only access to the
# runtime secrets needed by the AgentSwarm processes - and nothing else.

# Runtime app secrets (master keys, model providers, etc).
path "secret/data/yieldswarm/runtime/+" {
  capabilities = ["read"]
}

# RPC endpoints needed at runtime by agents.
path "secret/data/yieldswarm/rpc/+" {
  capabilities = ["read"]
}

# Optional: encrypt/decrypt via transit (envelope crypto for wallets).
path "transit/encrypt/yieldswarm-app"     { capabilities = ["update"] }
path "transit/decrypt/yieldswarm-app"     { capabilities = ["update"] }
path "transit/encrypt/yieldswarm-wallets" { capabilities = ["update"] }
path "transit/decrypt/yieldswarm-wallets" { capabilities = ["update"] }

# Self-token lifecycle so the entrypoint can renew before TTL.
path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
path "sys/capabilities-self"  { capabilities = ["update"] }

# Explicit deny: workload must never see cloud provider credentials.
path "secret/data/yieldswarm/cloud/*" {
  capabilities = ["deny"]
}
path "secret/data/yieldswarm/admin/*" {
  capabilities = ["deny"]
}
