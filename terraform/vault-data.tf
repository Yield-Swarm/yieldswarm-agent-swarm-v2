# =============================================================================
# Vault Data Sources — reads all provider secrets at plan/apply time
# YieldSwarm AgentSwarm OS v2.0
#
# These data sources are the single point of truth for secrets in Terraform.
# All provider configurations in providers.tf reference these data objects.
# =============================================================================

locals {
  env = var.vault_environment
}

# -----------------------------------------------------------------------------
# Infrastructure provider credentials
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "azure" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/infra/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/infra/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/infra/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/infra/digitalocean"
}

# -----------------------------------------------------------------------------
# RPC endpoints — used for infra outputs and monitoring configuration
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "rpc_solana" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/rpc/solana"
}

# -----------------------------------------------------------------------------
# CI/CD integration tokens — read here so Terraform can pass them to resources
# (e.g. configuring a Container App with the correct GitHub token)
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "integrations_productivity" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/integrations/productivity"
}

# -----------------------------------------------------------------------------
# Monitoring config — for alerting / Prometheus resource setup
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "monitoring" {
  mount = "secret"
  name  = "yieldswarm/${local.env}/monitoring/config"
}
