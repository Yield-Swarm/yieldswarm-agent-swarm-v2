locals {
  effective_resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
}

resource "azurerm_resource_group" "this" {
  count = var.enabled && var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  count = var.enabled ? 1 : 0

  name                = var.vmss_name
  resource_group_name = local.effective_resource_group_name
  location            = var.location
  sku                 = var.sku
  instances           = var.instance_count
  upgrade_mode        = "Manual"

  admin_username                  = var.admin_username
  disable_password_authentication = true
  custom_data                     = var.custom_data
  source_image_id                 = var.source_image_id

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "${var.vmss_name}-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.subnet_id
    }
  }

  tags = var.tags
}
