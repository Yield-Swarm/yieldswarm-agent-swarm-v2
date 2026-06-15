terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "environment" { type = string }
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "location" { type = string }

locals {
  name_prefix = "apn-${var.environment}"
  common_tags = {
    project     = "apn"
    environment = var.environment
    managed_by  = "terraform"
    secret_src  = "vault"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Azure-side Key Vault that mirrors a curated subset of platform secrets
# for services that can only read from Azure Key Vault (App Service /
# Functions). The mirror is populated by a separate sync job that
# authenticates to HashiCorp Vault with the apn-terraform AppRole, so
# the source of truth stays in HashiCorp Vault.
resource "azurerm_key_vault" "this" {
  name                          = substr(replace("${local.name_prefix}-kv", "-", ""), 0, 24)
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30
  rbac_authorization_enabled    = true
  public_network_access_enabled = false

  tags = local.common_tags
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}
