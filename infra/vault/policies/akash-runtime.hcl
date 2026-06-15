# =============================================================================
# Policy: akash-runtime
# Bound to the AppRole used by workloads running on Akash (and any other
# container runtime). Grants READ-ONLY access to the application runtime
# secrets and RPC endpoints injected by the container entrypoint at boot.
# It must NOT see cloud-provider provisioning credentials (cloud/*).
# =============================================================================

# Application runtime secrets (master keys, encryption keys, LLM/API keys).
path "kv/data/yieldswarm/app/*" {
  capabilities = ["read"]
}

# RPC / blockchain endpoints used by the agents at runtime.
path "kv/data/yieldswarm/rpc/*" {
  capabilities = ["read"]
}

# Metadata reads so the entrypoint can resolve the latest version.
path "kv/metadata/yieldswarm/app/*" {
  capabilities = ["read", "list"]
}
path "kv/metadata/yieldswarm/rpc/*" {
  capabilities = ["read", "list"]
}

# Self token lifecycle management.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
