terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "prod_group" {
  name     = "YieldSwarmProd"
  location = var.azure_prod_location
}

resource "azurerm_resource_group" "backup_group" {
  name     = "AzureBackupRG_australiaeast_1"
  location = var.azure_backup_location
}

resource "azurerm_virtual_network" "prod_vnet" {
  name                = "ys-prod-vnet"
  location            = azurerm_resource_group.prod_group.location
  resource_group_name = azurerm_resource_group.prod_group.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "prod_subnet" {
  name                 = "ys-prod-subnet"
  resource_group_name  = azurerm_resource_group.prod_group.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_network_interface" "primary_nic" {
  name                = "ys-primary-nic"
  location            = azurerm_resource_group.prod_group.location
  resource_group_name = azurerm_resource_group.prod_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prod_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "primary_engine" {
  name                = "YieldSwarmHotstandby"
  resource_group_name = azurerm_resource_group.prod_group.name
  location            = azurerm_resource_group.prod_group.location
  size                = var.primary_vm_size
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  network_interface_ids = [azurerm_network_interface.primary_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-swarm.yaml.tpl", {
    agent_count_total  = var.agent_count_total
    cron_shard_count   = var.cron_shard_count
    agents_per_shard   = var.agents_per_shard
  }))
}

resource "azurerm_cosmosdb_account" "cosmos_document_db" {
  name                = var.cosmos_account_name
  location            = azurerm_resource_group.backup_group.location
  resource_group_name = azurerm_resource_group.backup_group.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = var.azure_backup_location
    failover_priority = 0
  }

  geo_location {
    location          = var.azure_dr_location
    failover_priority = 1
  }

  geo_location {
    location          = var.azure_prod_location
    failover_priority = 2
  }
}

output "primary_vm_id" {
  value = azurerm_linux_virtual_machine.primary_engine.id
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.cosmos_document_db.endpoint
}

output "shard_config" {
  value = {
    agent_count_total = var.agent_count_total
    cron_shard_count  = var.cron_shard_count
    agents_per_shard    = var.agents_per_shard
  }
}
