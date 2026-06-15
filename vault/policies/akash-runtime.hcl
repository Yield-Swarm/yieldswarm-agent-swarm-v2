# Akash container runtime policy — least privilege for running agents.

path "secret/data/yieldswarm/akash/runtime" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/akash/runtime" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/rpc/solana" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/rpc/solana" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/rpc/failover" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/rpc/failover" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/agents/shared" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/agents/shared" {
  capabilities = ["read", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
