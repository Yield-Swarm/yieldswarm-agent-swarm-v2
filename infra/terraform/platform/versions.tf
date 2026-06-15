terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0"
    }
    runpod = {
      source  = "runpod/runpod"
      version = ">= 0.0.6"
    }
    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.22.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.44.0"
    }
  }
}
