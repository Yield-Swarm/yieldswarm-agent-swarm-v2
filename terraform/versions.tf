# =============================================================================
# Terraform Version Constraints
# YieldSwarm AgentSwarm OS v2.0
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.36"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.19"
    }
    runpod = {
      source  = "runpod/runpod"
      version = "~> 1.0"
    }
  }

  # Remote state — Azure Blob Storage backend
  # Replace placeholders before running terraform init.
  backend "azurerm" {
    resource_group_name  = "yieldswarm-tfstate-rg"
    storage_account_name = "yieldswarmtfstate"
    container_name       = "tfstate"
    key                  = "agentswarm.terraform.tfstate"
    # Credentials for the backend itself come from ARM_* environment variables
    # (or Azure MSI), NOT from Vault. This avoids a chicken-and-egg problem.
  }
}
