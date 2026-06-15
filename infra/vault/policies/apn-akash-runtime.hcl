# apn-akash-runtime: policy bound to the `apn-akash-runtime` AppRole.
#
# Mounted into the Akash Docker entrypoint via Vault Agent (AppRole
# auto-auth). The runtime container reads operational secrets and can
# perform envelope encryption / signing through Transit, but cannot
# enumerate the apn tree or touch provider credentials used by IaC.

# Core platform secrets (master key, encryption keys, TEE signing key).
path "kv/data/apn/core" {
  capabilities = ["read"]
}

# LLM provider keys (OpenAI, Anthropic, Gemini, Grok, etc.).
path "kv/data/apn/llm/*" {
  capabilities = ["read"]
}

# RPC + chain API keys used by the agent swarm.
path "kv/data/apn/rpc/*" {
  capabilities = ["read"]
}

# Third-party integration tokens (Notion, Linear, Vercel, GitHub,
# Telegram, X, Meta Ads, Unstoppable Domains, etc.).
path "kv/data/apn/integrations/*" {
  capabilities = ["read"]
}

# DePIN / hardware tokens (Helium, RunPod GPU keys, Grass, SmartThings,
# Utility API, Tesla integration).
path "kv/data/apn/depin/*" {
  capabilities = ["read"]
}

# Envelope encryption + TEE signing through Transit. The runtime can
# encrypt and decrypt but never read the raw key material.
path "transit/encrypt/apn-wallet-encryption" {
  capabilities = ["update"]
}

path "transit/decrypt/apn-wallet-encryption" {
  capabilities = ["update"]
}

path "transit/encrypt/apn-db-encryption" {
  capabilities = ["update"]
}

path "transit/decrypt/apn-db-encryption" {
  capabilities = ["update"]
}

path "transit/sign/apn-tee-signing/*" {
  capabilities = ["update"]
}

path "transit/verify/apn-tee-signing/*" {
  capabilities = ["update"]
}

# Token self-management for the Vault Agent sidecar.
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
