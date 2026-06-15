terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "~> 1.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }

    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.0"
    }
  }
}
