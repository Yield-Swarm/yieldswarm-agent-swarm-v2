terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.45"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    runpod = {
      source  = "runpod/runpod"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Backend is intentionally not set here.  In CI we pass
  # `-backend-config=backend-${ENV}.hcl` so prod / staging state are isolated.
  # Local plans can run with `terraform init -backend=false`.
  backend "remote" {}
}
