# vault/policies/akash-agent.hcl
# Least-privilege read access for the Akash agent container AppRole.
# Each running container authenticates with its own secret_id (wrapped, single-use).
# Grants access to runtime agent secrets only — no cloud infra credentials.
#
# Apply:
#   vault policy write akash-agent vault/policies/akash-agent.hcl

# Agent master keys and LLM API keys
path "secret/data/agents/master" {
  capabilities = ["read"]
}

path "secret/metadata/agents/master" {
  capabilities = ["read"]
}

# Blockchain / wallet secrets
path "secret/data/agents/blockchain" {
  capabilities = ["read"]
}

path "secret/metadata/agents/blockchain" {
  capabilities = ["read"]
}

# DePIN node keys (Helium, Grass, GPU cluster)
path "secret/data/agents/depin" {
  capabilities = ["read"]
}

path "secret/metadata/agents/depin" {
  capabilities = ["read"]
}

# Integration API keys (Notion, Linear, GitHub, etc.)
path "secret/data/agents/integrations" {
  capabilities = ["read"]
}

path "secret/metadata/agents/integrations" {
  capabilities = ["read"]
}

# RPC endpoints consumed by agents at runtime
path "secret/data/rpc/*" {
  capabilities = ["read"]
}

path "secret/metadata/rpc/*" {
  capabilities = ["read", "list"]
}

# Allow the agent to look up and renew its own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
