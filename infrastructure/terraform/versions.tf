terraform {
  required_version = ">= 1.6.0"

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
      version = "~> 2.43"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    # RunPod does not yet ship a HashiCorp-verified provider; we use the
    # community provider gated behind `http` for portability. To switch to
    # the runpod-io/runpod provider once it stabilises, replace the
    # `restapi` references in runpod.tf.
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.19"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # Configure remote state in your environment-specific overlay (e.g.
  # backend.azurerm.tf or backend.s3.tf). NEVER store state on a developer
  # laptop in production - state contains the resolved secret values
  # returned by `vault_kv_secret_v2` data sources.
  backend "azurerm" {}
}
