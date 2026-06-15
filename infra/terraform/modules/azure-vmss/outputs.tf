output "summary" {
  description = "Azure VMSS fallback summary."
  value = {
    provider            = "azure"
    resource_group      = local.rg_name
    scale_set_name      = azurerm_linux_virtual_machine_scale_set.this.name
    location            = var.location
    vm_size             = var.vm_size
    worker_count        = var.worker_count
    using_packer_image  = !local.use_marketplace_image
    scale_set_unique_id = azurerm_linux_virtual_machine_scale_set.this.unique_id
  }
}
