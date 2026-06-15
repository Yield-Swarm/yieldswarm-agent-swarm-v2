# =============================================================================
# Azure resources for YieldSwarm.
#
# We create:
#   * a resource group
#   * a Key Vault that mirrors the RPC + runtime secrets for Azure-native
#     workloads (AKS, Functions) that already have managed-identity bindings
#   * an Azure Container Apps environment placeholder (actual app definitions
#     live in their own module)
#
# All credentials come from the Vault data sources in vault.tf.
# =============================================================================

resource "azurerm_resource_group" "main" {
  count    = var.enabled_clouds.azure ? 1 : 0
  name     = try(local.azure_secret.resource_group, "yieldswarm-${var.environment}")
  location = try(local.azure_secret.location, "eastus")
  tags     = local.common_tags
}

data "azurerm_client_config" "current" {
  count = var.enabled_clouds.azure ? 1 : 0
}

resource "azurerm_key_vault" "rpc_mirror" {
  count                         = var.enabled_clouds.azure ? 1 : 0
  name                          = "yswarm-${var.environment}-kv"
  location                      = azurerm_resource_group.main[0].location
  resource_group_name           = azurerm_resource_group.main[0].name
  tenant_id                     = data.azurerm_client_config.current[0].tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = local.common_tags
}

# Grant the Terraform service principal permission to write secrets into the
# RBAC-enabled Key Vault. Without this the for_each below would fail with 403.
resource "azurerm_role_assignment" "tf_kv_secrets_officer" {
  count                = var.enabled_clouds.azure ? 1 : 0
  scope                = azurerm_key_vault.rpc_mirror[0].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current[0].object_id
}

# Mirror only the RPC bundle into Azure Key Vault; everything else stays in
# Vault and is fetched at runtime by the Akash entrypoint.
resource "azurerm_key_vault_secret" "rpc" {
  for_each = var.enabled_clouds.azure ? local.rpc_secret : {}

  depends_on = [azurerm_role_assignment.tf_kv_secrets_officer]

  name         = replace(each.key, "_", "-")
  value        = each.value
  key_vault_id = azurerm_key_vault.rpc_mirror[0].id

  content_type = "yieldswarm/rpc"
  tags         = local.common_tags

  lifecycle {
    # The source of truth is Vault; if a value changes there, recreate.
    create_before_destroy = true
  }
}
