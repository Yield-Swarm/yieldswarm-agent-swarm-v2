# =============================================================================
# Vault Policy: runpod
# YieldSwarm AgentSwarm OS v2.0
#
# Minimal policy for processes running directly on RunPod GPU clusters.
# Read access is scoped to only the secrets needed for RunPod workloads.
# =============================================================================

# --- RunPod own credentials (self-read for re-auth) ---
path "secret/data/yieldswarm/+/infra/runpod" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/runpod" {
  capabilities = ["read", "list"]
}

# --- LLM keys (for inference workloads) ---
path "secret/data/yieldswarm/+/llm/providers" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/llm/providers" {
  capabilities = ["read", "list"]
}

# --- RPC access (for on-chain reporting) ---
path "secret/data/yieldswarm/+/rpc/solana" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/rpc/solana" {
  capabilities = ["read", "list"]
}

# --- Monitoring (to report metrics) ---
path "secret/data/yieldswarm/+/monitoring/config" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/monitoring/config" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
