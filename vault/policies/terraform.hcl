# =============================================================================
# Vault Policy: terraform
# YieldSwarm AgentSwarm OS v2.0
#
# Attached to the "terraform" AppRole. Terraform uses this policy to read
# provider credentials (Azure, RunPod, Vultr, DigitalOcean) and RPC endpoints
# from Vault at plan/apply time. Write access is intentionally omitted.
# =============================================================================

# --- Azure credentials ---
path "secret/data/yieldswarm/+/infra/azure" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/azure" {
  capabilities = ["read", "list"]
}

# --- RunPod credentials ---
path "secret/data/yieldswarm/+/infra/runpod" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/runpod" {
  capabilities = ["read", "list"]
}

# --- Vultr credentials ---
path "secret/data/yieldswarm/+/infra/vultr" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/vultr" {
  capabilities = ["read", "list"]
}

# --- DigitalOcean credentials ---
path "secret/data/yieldswarm/+/infra/digitalocean" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/digitalocean" {
  capabilities = ["read", "list"]
}

# --- RPC endpoints (read-only for infra provisioning) ---
path "secret/data/yieldswarm/+/rpc/solana" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/rpc/solana" {
  capabilities = ["read", "list"]
}

# --- GitHub / Vercel tokens (for CI-triggered Terraform) ---
path "secret/data/yieldswarm/+/integrations/productivity" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/integrations/productivity" {
  capabilities = ["read", "list"]
}

# Token self-management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
