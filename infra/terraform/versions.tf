terraform {
  required_version = ">= 1.6.0"

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
      source = "runpod/runpod"
    }
  }
}
