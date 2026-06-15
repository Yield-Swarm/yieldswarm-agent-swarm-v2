output "resource_group_name" {
  value = var.enabled ? local.effective_resource_group_name : null
}

output "vmss_id" {
  value = var.enabled ? azurerm_linux_virtual_machine_scale_set.this[0].id : null
}

output "vmss_name" {
  value = var.enabled ? azurerm_linux_virtual_machine_scale_set.this[0].name : null
}
