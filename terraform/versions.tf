terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.45"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.23"
    }
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "~> 1.0"
    }
  }

  # Uncomment and configure for production remote state.
  # backend "azurerm" {
  #   resource_group_name  = "yieldswarm-tfstate"
  #   storage_account_name = "yieldswarmtfstate"
  #   container_name       = "tfstate"
  #   key                  = "yieldswarm.terraform.tfstate"
  # }
}
