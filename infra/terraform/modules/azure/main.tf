## Azure module - resource group, key vault (for cloud-side replication of a
## subset of Vault secrets used by Azure-managed services), and a storage
## account used by the AgentSwarm shard state.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

resource "random_string" "sa_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
  tags     = merge(var.tags, { environment = var.environment })
}

resource "azurerm_storage_account" "state" {
  name                            = substr("ysw${var.environment}${random_string.sa_suffix.result}", 0, 24)
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }

  tags = merge(var.tags, { environment = var.environment })
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                          = substr("ysw-kv-${var.environment}-${random_string.sa_suffix.result}", 0, 24)
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30
  enable_rbac_authorization     = true
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = merge(var.tags, { environment = var.environment })
}
