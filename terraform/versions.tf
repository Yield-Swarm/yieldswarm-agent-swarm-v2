terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.0"
    }
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "1.0.1"
    }
  }

  # Configure remote state backend in production (example):
  # backend "azurerm" {
  #   resource_group_name  = "yieldswarm-tfstate"
  #   storage_account_name = "yieldswarmtfstate"
  #   container_name       = "tfstate"
  #   key                  = "yieldswarm.terraform.tfstate"
  # }
}
