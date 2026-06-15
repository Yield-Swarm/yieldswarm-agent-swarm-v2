# =============================================================================
# Azure Resources
# YieldSwarm AgentSwarm OS v2.0
#
# Credentials come from data.vault_kv_secret_v2.azure (vault-data.tf).
# Never put ARM_CLIENT_SECRET or any secret in this file.
# =============================================================================

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "agents" {
  name     = var.azure_resource_group
  location = var.azure_location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Container App Environment (for hosting agent workloads on Azure)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "agents" {
  name                = "yieldswarm-agents-law"
  location            = azurerm_resource_group.agents.location
  resource_group_name = azurerm_resource_group.agents.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "agents" {
  name                       = "yieldswarm-cae"
  location                   = azurerm_resource_group.agents.location
  resource_group_name        = azurerm_resource_group.agents.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.agents.id
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault (for Vault auto-unseal key storage — separate from HashiCorp Vault)
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "vault_unseal" {
  name                        = "ys-vault-unseal-kv"
  location                    = azurerm_resource_group.agents.location
  resource_group_name         = azurerm_resource_group.agents.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"    # Premium required for HSM-backed keys
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true         # Required for Vault auto-unseal

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    # Add your Vault VM/node egress IPs here:
    # ip_rules = ["<vault_node_public_ip>/32"]
  }

  tags = var.tags
}

# RSA key used for Vault auto-unseal (BYOK)
resource "azurerm_key_vault_key" "vault_unseal" {
  name         = "vault-unseal-key"
  key_vault_id = azurerm_key_vault.vault_unseal.id
  key_type     = "RSA-HSM"
  key_size     = 4096

  key_opts = ["wrapKey", "unwrapKey"]

  depends_on = [azurerm_key_vault.vault_unseal]
}

# ---------------------------------------------------------------------------
# Storage account for Terraform remote state (bootstrap resource)
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "tfstate" {
  name                     = "yieldswarmtfstate"
  resource_group_name      = azurerm_resource_group.agents.name
  location                 = azurerm_resource_group.agents.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
