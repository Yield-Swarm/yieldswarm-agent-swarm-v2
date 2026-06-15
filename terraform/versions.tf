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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  # Production: configure remote backend (Azure Storage, S3, etc.)
  # backend "azurerm" {
  #   resource_group_name  = "yieldswarm-tfstate"
  #   storage_account_name = "yieldswarmtfstate"
  #   container_name       = "tfstate"
  #   key                  = "yieldswarm.terraform.tfstate"
  # }
}
