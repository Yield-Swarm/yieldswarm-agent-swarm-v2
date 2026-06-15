terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    runpod = {
      source = "runpod/runpod"
    }
    vault = {
      source = "hashicorp/vault"
    }
    vultr = {
      source = "vultr/vultr"
    }
  }
}
