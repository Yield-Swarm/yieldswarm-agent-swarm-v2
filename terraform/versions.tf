terraform {
  required_version = ">= 1.6.0"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.21.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.40.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}
