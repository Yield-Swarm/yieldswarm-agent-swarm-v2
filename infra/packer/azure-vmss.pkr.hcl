packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.0.0"
    }
  }
}

variable "subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

variable "client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type      = string
  default   = env("ARM_CLIENT_SECRET")
  sensitive = true
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "build_resource_group_name" {
  type    = string
  default = "helixchain-packer-rg"
}

variable "managed_image_resource_group_name" {
  type    = string
  default = "helixchain-prod-rg"
}

variable "managed_image_name" {
  type    = string
  default = "helixchain-azure"
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

source "azure-arm" "helixchain" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  location                          = var.location
  vm_size                           = var.vm_size
  os_type                           = "Linux"
  image_publisher                   = "Canonical"
  image_offer                       = "0001-com-ubuntu-server-jammy"
  image_sku                         = "22_04-lts-gen2"
  managed_image_name                = var.managed_image_name
  managed_image_resource_group_name = var.managed_image_resource_group_name
  build_resource_group_name         = var.build_resource_group_name
  ssh_username                      = var.ssh_username

  azure_tags = {
    workload = "helixchain"
    env      = "prod"
    built_by = "packer"
  }
}

build {
  name    = "azure-vmss-image"
  sources = ["source.azure-arm.helixchain"]

  provisioner "shell" {
    script = "${path.root}/scripts/bootstrap.sh"
  }
}
