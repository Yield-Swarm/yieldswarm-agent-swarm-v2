output "container_app_environment_id" {
  description = "Azure Container Apps environment resource ID."
  value       = azurerm_container_app_environment.agentswarm.id
}

output "storage_account_name" {
  description = "Azure Storage Account name."
  value       = azurerm_storage_account.agentswarm.name
}

output "container_app_ids" {
  description = "IDs of all shard Container Apps."
  value       = azurerm_container_app.shard[*].id
}

output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.agentswarm.name
}
