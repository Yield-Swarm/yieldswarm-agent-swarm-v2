# =============================================================================
# Vault Policy: vultr
# YieldSwarm AgentSwarm OS v2.0
#
# Minimal policy for processes deployed on Vultr infrastructure.
# =============================================================================

path "secret/data/yieldswarm/+/infra/vultr" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/vultr" {
  capabilities = ["read", "list"]
}

# Core agent keys needed by Vultr-hosted processes
path "secret/data/yieldswarm/+/agents/core" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/agents/core" {
  capabilities = ["read", "list"]
}

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
