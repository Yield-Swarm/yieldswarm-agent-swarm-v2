# =============================================================================
# Vault Policy: akash-agents
# YieldSwarm AgentSwarm OS v2.0
#
# Attached to the "akash-agents" AppRole. Grants the Vault Agent sidecar
# inside each Akash container read access to all operational secrets.
# No write or delete capabilities are granted.
# =============================================================================

# --- Core agent identity secrets ---
path "secret/data/yieldswarm/+/agents/core" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/agents/core" {
  capabilities = ["read", "list"]
}

# --- LLM / AI provider keys ---
path "secret/data/yieldswarm/+/llm/providers" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/llm/providers" {
  capabilities = ["read", "list"]
}

# --- Solana RPC endpoints ---
path "secret/data/yieldswarm/+/rpc/solana" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/rpc/solana" {
  capabilities = ["read", "list"]
}

# --- On-chain / blockchain keys ---
path "secret/data/yieldswarm/+/blockchain/keys" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/blockchain/keys" {
  capabilities = ["read", "list"]
}

# --- DePIN hardware keys ---
path "secret/data/yieldswarm/+/depin/hardware" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/depin/hardware" {
  capabilities = ["read", "list"]
}

# --- Productivity integrations ---
path "secret/data/yieldswarm/+/integrations/productivity" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/integrations/productivity" {
  capabilities = ["read", "list"]
}

# --- Social / marketing ---
path "secret/data/yieldswarm/+/integrations/social" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/integrations/social" {
  capabilities = ["read", "list"]
}

# --- Payments ---
path "secret/data/yieldswarm/+/integrations/payments" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/integrations/payments" {
  capabilities = ["read", "list"]
}

# --- Monitoring configuration ---
path "secret/data/yieldswarm/+/monitoring/config" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/monitoring/config" {
  capabilities = ["read", "list"]
}

# Token self-management (for Vault Agent token renewal)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
