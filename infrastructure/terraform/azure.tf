# azure.tf
# Configures AzureRM with credentials retrieved from Vault.
# Provides a minimal "landing zone" (resource group + storage account for
# Terraform state) so the rest of the AzureRM modules in this repo can
# reuse it.

provider "azurerm" {
  features {}

  # NOTE: We intentionally do NOT set client_id/secret as environment
  # variables; doing so would put them in the process env table where
  # any sidecar could read them. Vault data is injected explicitly here.
  client_id       = try(local.azure["client_id"], null)
  client_secret   = try(local.azure["client_secret"], null)
  tenant_id       = try(local.azure["tenant_id"], null)
  subscription_id = try(local.azure["subscription_id"], null)
}

resource "azurerm_resource_group" "yieldswarm" {
  count    = var.enable_azure ? 1 : 0
  name     = "rg-yieldswarm-${var.environment}"
  location = try(local.azure["default_location"], "eastus2")
  tags     = var.default_tags
}

# Sample workload: a storage account used by AgentSwarm cron jobs for
# checkpointing. Demonstrates that the provider authenticates with the
# Vault-sourced credentials.
resource "azurerm_storage_account" "checkpoints" {
  count                         = var.enable_azure ? 1 : 0
  name                          = "yswarm${var.environment}chk${random_id.azure_suffix[0].hex}"
  resource_group_name           = azurerm_resource_group.yieldswarm[0].name
  location                      = azurerm_resource_group.yieldswarm[0].location
  account_tier                  = "Standard"
  account_replication_type      = "ZRS"
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = false
  public_network_access_enabled = false

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }

  tags = var.default_tags
}

resource "random_id" "azure_suffix" {
  count       = var.enable_azure ? 1 : 0
  byte_length = 3
}
