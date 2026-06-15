terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    runpod = {
      source = "decentralized-infrastructure/runpod"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.1.0"
    }
    vultr = {
      source = "vultr/vultr"
    }
  }
}
