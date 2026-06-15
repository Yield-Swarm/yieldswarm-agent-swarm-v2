resource "azurerm_resource_group" "main" {
  count = var.azure_create_resource_group ? 1 : 0

  name     = local.azure_secrets.resource_group
  location = local.azure_secrets.location
  tags     = local.common_tags
}

# Example: Container App environment for AgentSwarm workloads.
# Secrets are never stored in Terraform state as plain resources — only Vault paths are referenced.
resource "azurerm_container_app_environment" "agentswarm" {
  count = var.azure_create_resource_group ? 1 : 0

  name                = "${var.project_name}-${var.environment}-cae"
  location            = azurerm_resource_group.main[0].location
  resource_group_name = azurerm_resource_group.main[0].name
  tags                = local.common_tags
}

output "azure_resource_group" {
  description = "Azure resource group name from Vault."
  value       = nonsensitive(local.azure_secrets.resource_group)
}

output "azure_location" {
  description = "Azure region from Vault."
  value       = nonsensitive(local.azure_secrets.location)
}

output "azure_container_app_env_id" {
  description = "Container App Environment ID when created."
  value       = try(azurerm_container_app_environment.agentswarm[0].id, null)
}
