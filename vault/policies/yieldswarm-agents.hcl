# ============================================================
# Policy: yieldswarm-agents
# Scope : Runtime read access for AI agent processes.
#         Covers LLM keys, RPC endpoints, blockchain signing
#         keys, DePIN hardware keys, and core auth material.
#
#         Intended identity: AppRole role "yieldswarm-agents"
#         Token TTL: 24 h, renewable up to 7 days
# ============================================================

path "secret/data/yieldswarm/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/llm" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/blockchain" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/depin" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/integrations" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/monitoring" {
  capabilities = ["read"]
}

# List metadata only — no data read on other paths
path "secret/metadata/yieldswarm/*" {
  capabilities = ["list"]
}

# Token lifecycle
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
