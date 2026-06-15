terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.46"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.27"
    }
    runpod = {
      source  = "runpod/runpod"
      version = "~> 1.5"
    }
  }
}
