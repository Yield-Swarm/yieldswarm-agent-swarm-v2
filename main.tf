provider "azurerm" {
  features {}

  subscription_id = var.enable_azure_fallback ? var.azure_subscription_id : null
  tenant_id       = var.enable_azure_fallback ? var.azure_tenant_id : null
  client_id       = var.enable_azure_fallback ? var.azure_client_id : null
  client_secret   = var.enable_azure_fallback ? var.azure_client_secret : null
}

locals {
  common_tags = {
    project     = "yieldswarm"
    environment = "production"
    managed_by  = "terraform-cloud"
  }
}

# Akash targeting metadata used by deployment automation.
resource "null_resource" "akash_targeting" {
  triggers = {
    node      = var.akash_node
    chain_id  = var.akash_chain_id
    key_name  = var.akash_key_name
    gpu_model = var.akash_gpu_model_hint
  }
}

resource "azurerm_resource_group" "fallback" {
  count    = var.enable_azure_fallback ? 1 : 0
  name     = var.azure_resource_group_name
  location = var.azure_location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "fallback" {
  count               = var.enable_azure_fallback ? 1 : 0
  name                = "${var.azure_vmss_name}-vnet"
  address_space       = ["10.35.0.0/16"]
  location            = azurerm_resource_group.fallback[0].location
  resource_group_name = azurerm_resource_group.fallback[0].name
  tags                = local.common_tags
}

resource "azurerm_subnet" "fallback" {
  count                = var.enable_azure_fallback ? 1 : 0
  name                 = "${var.azure_vmss_name}-subnet"
  resource_group_name  = azurerm_resource_group.fallback[0].name
  virtual_network_name = azurerm_virtual_network.fallback[0].name
  address_prefixes     = ["10.35.1.0/24"]
}

resource "azurerm_linux_virtual_machine_scale_set" "fallback" {
  count               = var.enable_azure_fallback ? 1 : 0
  name                = var.azure_vmss_name
  resource_group_name = azurerm_resource_group.fallback[0].name
  location            = azurerm_resource_group.fallback[0].location
  sku                 = var.azure_vm_size
  instances           = var.azure_instance_count
  admin_username      = var.azure_admin_username

  disable_password_authentication = true
  overprovision                   = false
  upgrade_mode                    = "Manual"

  admin_ssh_key {
    username   = var.azure_admin_username
    public_key = var.azure_admin_ssh_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.azure_vmss_name}-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.fallback[0].id
    }
  }

  custom_data = base64encode(<<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y curl jq
  EOT
  )

  tags = local.common_tags
}
