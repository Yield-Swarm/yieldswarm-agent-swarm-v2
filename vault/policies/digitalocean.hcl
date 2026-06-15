# =============================================================================
# Vault Policy: digitalocean
# YieldSwarm AgentSwarm OS v2.0
#
# Minimal policy for processes deployed on DigitalOcean infrastructure.
# =============================================================================

path "secret/data/yieldswarm/+/infra/digitalocean" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/infra/digitalocean" {
  capabilities = ["read", "list"]
}

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
