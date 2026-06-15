terraform {
  required_version = ">= 1.10.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "= 5.9.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.77.0"
    }
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "= 1.0.1"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "= 2.31.2"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "= 2.88.0"
    }
  }
}
