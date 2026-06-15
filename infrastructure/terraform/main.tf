# main.tf
# Top-level orchestration of the YieldSwarm infrastructure. The bulk of
# the work lives in the provider-specific files:
#
#   vault.tf         - Vault provider + KV data sources
#   azure.tf         - AzureRM landing zone (resource group + storage)
#   runpod.tf        - RunPod API client (REST)
#   vultr.tf         - Vultr landing zone
#   digitalocean.tf  - DigitalOcean project + registry
#   rpc.tf           - RPC endpoint smoke checks
#
# This file holds cross-cutting concerns: tags, environment guardrails,
# and a single sentinel output that proves Vault auth succeeded.

locals {
  tags = merge(var.default_tags, {
    environment = var.environment
  })
}

output "vault_auth_ok" {
  description = "True if Vault AppRole login succeeded and KV reads returned. Use as a smoke check in CI."
  value = alltrue([
    length(keys(local.rpc.solana)) > 0,
    !var.enable_azure || length(keys(local.azure)) > 0,
    !var.enable_runpod || length(keys(local.runpod)) > 0,
    !var.enable_vultr || length(keys(local.vultr)) > 0,
    !var.enable_digitalocean || length(keys(local.digitalocean)) > 0,
  ])
}
