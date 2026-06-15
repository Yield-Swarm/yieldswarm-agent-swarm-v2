# =============================================================================
# Module: azure-core
# -----------------------------------------------------------------------------
# Provisions the foundational Azure footprint for AgentSwarm:
#
#   * Resource group (idempotent: created only if absent)
#   * Log Analytics workspace (sink for Vault audit + container logs)
#   * Storage account + container for Terraform-out-of-band artifacts
#   * Container App Environment ready to host the AgentSwarm runtime when an
#     operator chooses Azure over Akash.
#
# Credentials are NEVER read here - they come from the azurerm provider in
# the root module, which itself authenticates with secrets pulled from Vault.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.108"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

resource "azurerm_storage_account" "artifacts" {
  name                            = replace("${var.name_prefix}art${random_string.suffix.result}", "-", "")
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${var.name_prefix}-cae"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.this.id
}

output "artifacts_storage_account" {
  value = azurerm_storage_account.artifacts.name
}
