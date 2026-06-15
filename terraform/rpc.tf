# RPC secrets from Vault — used for health checks and failover configuration.
# API keys are never output; only connectivity status is exposed.

data "http" "solana_health" {
  url = local.rpc.solana_rpc_url

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    jsonrpc = "2.0"
    id      = 1
    method  = "getHealth"
  })

  method = "POST"
}

locals {
  rpc_failover_list = try(jsondecode(local.rpc.failover_rpc_list), [])
  solana_healthy    = data.http.solana_health.status_code == 200
}

resource "azurerm_key_vault_secret" "rpc_failover_config" {
  name         = "rpc-failover-config"
  value        = local.rpc.failover_rpc_list
  key_vault_id = azurerm_key_vault.secrets.id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault" "secrets" {
  name                       = "ys-rpc-${var.environment}"
  location                   = azurerm_resource_group.yieldswarm.location
  resource_group_name        = azurerm_resource_group.yieldswarm.name
  tenant_id                  = local.azure.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  tags                       = local.common_tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.secrets.id
  tenant_id    = local.azure.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete"]
}

data "azurerm_client_config" "current" {}

output "rpc_status" {
  description = "RPC endpoint health (no secrets exposed)"
  value = {
    primary_healthy   = local.solana_healthy
    failover_count    = length(local.rpc_failover_list)
    helius_configured = local.rpc.helius_api_key != "REPLACE_ME"
    birdeye_configured = local.rpc.birdeye_api_key != "REPLACE_ME"
    jupiter_configured = local.rpc.jupiter_api_key != "REPLACE_ME"
  }
}
