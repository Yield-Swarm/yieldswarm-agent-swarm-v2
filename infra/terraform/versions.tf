terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }

    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }

    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = ">= 1.0.0"
    }

    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.0.0"
    }
  }
}
