terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.46.0"
    }
    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.21.0"
    }
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = ">= 1.0.1"
    }
  }
}

provider "vault" {
  # Configure with VAULT_ADDR, VAULT_TOKEN, VAULT_NAMESPACE, and TLS env vars.
}
