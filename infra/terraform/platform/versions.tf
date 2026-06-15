terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }

    digitalocean = {
      source = "digitalocean/digitalocean"
    }

    vultr = {
      source = "vultr/vultr"
    }

    runpod = {
      source = "decentralized-infrastructure/runpod"
    }
  }
}
