# Policy: akash-runtime
# Read-only access to secrets needed by running AgentSwarm containers.
# Assign to: the "akash-runtime" AppRole role.
# Containers authenticate via AppRole at startup and read exactly these paths.

# Core agent credentials (master key, encryption keys, TEE signing key)
path "secret/data/agentswarm/core" {
  capabilities = ["read"]
}

# LLM API keys (OpenAI, Grok, Gemini, Anthropic)
path "secret/data/agentswarm/llm" {
  capabilities = ["read"]
}

# Blockchain RPC endpoints and keys (Solana, Helius, Jupiter, etc.)
path "secret/data/agentswarm/rpc" {
  capabilities = ["read"]
}

# DePIN hardware access keys (Helium, Grass nodes, GPU cluster)
path "secret/data/agentswarm/depin" {
  capabilities = ["read"]
}

# Integration tokens (Notion, GitHub, Telegram, Linear)
path "secret/data/agentswarm/integrations" {
  capabilities = ["read"]
}

# Token self-renewal — agents run long-lived; they must renew their own tokens
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
