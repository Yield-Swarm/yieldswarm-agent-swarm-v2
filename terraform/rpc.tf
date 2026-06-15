# RPC configuration — secrets sourced from Vault, exposed as Terraform outputs
# for downstream consumers (monitoring, health checks, agent config).

resource "azurerm_key_vault_secret" "solana_rpc_url" {
  name         = "solana-rpc-url"
  value        = local.solana_rpc_url
  key_vault_id = azurerm_key_vault.rpc.id

  tags = {
    source = "hashicorp-vault"
  }
}

resource "azurerm_key_vault" "rpc" {
  name                = "yieldswarm-rpc-${var.environment}"
  location            = azurerm_resource_group.agents.location
  resource_group_name = azurerm_resource_group.agents.name
  tenant_id           = local.azure_creds["tenant_id"]
  sku_name            = "standard"

  access_policy {
    tenant_id = local.azure_creds["tenant_id"]
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set"]
  }

  tags = {
    environment = var.environment
  }
}

data "azurerm_client_config" "current" {}

# Health-check locals for RPC failover validation
locals {
  rpc_endpoints = concat(
    [local.solana_rpc_url],
    local.failover_rpc_list
  )
}

output "rpc_primary_url" {
  description = "Primary Solana RPC URL (from Vault)."
  value       = local.solana_rpc_url
  sensitive   = true
}

output "rpc_failover_count" {
  description = "Number of failover RPC endpoints configured."
  value       = length(local.failover_rpc_list)
}

output "rpc_all_endpoints" {
  description = "All RPC endpoints including failover (sensitive)."
  value       = local.rpc_endpoints
  sensitive   = true
}
