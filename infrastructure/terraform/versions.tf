terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
    # No official RunPod provider exists. We use the community REST provider
    # to drive the RunPod GraphQL endpoint with credentials from Vault.
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.19"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # Remote state must be encrypted; use whichever backend matches your env.
  # Example for Azure blob storage (recommended for this stack):
  #
  # backend "azurerm" {
  #   resource_group_name  = "yieldswarm-tfstate"
  #   storage_account_name = "yieldswarmtfstate"
  #   container_name       = "tfstate"
  #   key                  = "yieldswarm.tfstate"
  #   use_azuread_auth     = true
  # }
}
