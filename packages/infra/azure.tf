# Layer 14 & 15 — Azure Resource Manager + Kyle's production environment
# Usage: terraform -chdir=packages/infra init && terraform apply

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

variable "location" {
  type    = string
  default = "East US 2"
}

variable "owner" {
  type    = string
  default = "Kyle"
}

resource "azurerm_resource_group" "kyle_swarm_rg" {
  name     = "kyle-yieldswarm-core-prod-rg"
  location = var.location

  tags = {
    Environment = "Production"
    Owner       = var.owner
    Project     = "YieldSwarm-OS"
    Layer       = "14-15"
  }
}

resource "azurerm_kubernetes_cluster" "swarm_aks_cluster" {
  name                = "swarm-runtime-aks"
  location            = azurerm_resource_group.kyle_swarm_rg.location
  resource_group_name = azurerm_resource_group.kyle_swarm_rg.name
  dns_prefix          = "yieldswarmcore"

  default_node_pool {
    name       = "kylepool"
    node_count = 5
    vm_size    = "Standard_D8s_v5"
  }

  identity {
    type = "SystemAssigned"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.kyle_swarm_rg.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.swarm_aks_cluster.name
}
