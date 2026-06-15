terraform {
  required_version = ">= 1.5.0"

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
      source = "hashicorp/vault"
    }
    vultr = {
      source = "vultr/vultr"
    }
  }
}
