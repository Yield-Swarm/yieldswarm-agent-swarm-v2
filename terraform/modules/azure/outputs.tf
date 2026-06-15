output "resource_group_id" {
  description = "ID of the YieldSwarm Azure resource group."
  value       = azurerm_resource_group.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "location" {
  value = azurerm_resource_group.this.location
}
