output "environment" {
  value = var.environment
}

output "azure_resource_group" {
  value = azurerm_resource_group.yieldswarm.name
}

output "vault_addr" {
  value = var.vault_addr
}
