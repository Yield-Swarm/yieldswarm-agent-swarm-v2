###############################################################################
# Azure fallback: a Linux Virtual Machine Scale Set of AgentSwarm workers.
###############################################################################

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  create_rg = var.resource_group_name == ""
  rg_name   = local.create_rg ? azurerm_resource_group.this[0].name : var.resource_group_name
  base_name = "${var.name_prefix}-az"

  # Use a Packer image when provided, otherwise the Ubuntu 22.04 LTS marketplace image.
  use_marketplace_image = var.source_image_id == ""

  custom_data = base64encode(templatefile("${path.root}/templates/worker-bootstrap.sh.tftpl", {
    worker_image    = var.worker_image
    worker_provider = var.worker_provider
    worker_env      = var.worker_env
  }))
}

resource "azurerm_resource_group" "this" {
  count    = local.create_rg ? 1 : 0
  name     = "${local.base_name}-rg-${var.unique_suffix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.base_name}-vnet-${var.unique_suffix}"
  resource_group_name = local.rg_name
  location            = var.location
  address_space       = ["10.80.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "${local.base_name}-subnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.80.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = "${local.base_name}-nsg-${var.unique_suffix}"
  resource_group_name = local.rg_name
  location            = var.location
  tags                = var.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = "${local.base_name}-vmss-${var.unique_suffix}"
  resource_group_name = local.rg_name
  location            = var.location
  sku                 = var.vm_size
  instances           = var.worker_count
  admin_username      = var.admin_username
  custom_data         = local.custom_data
  upgrade_mode        = "Rolling"
  overprovision       = false
  tags                = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  source_image_id = local.use_marketplace_image ? null : var.source_image_id

  dynamic "source_image_reference" {
    for_each = local.use_marketplace_image ? [1] : []
    content {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${local.base_name}-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.this.id

      public_ip_address {
        name = "pub"
      }
    }
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 50
    pause_time_between_batches              = "PT2M"
  }
}
