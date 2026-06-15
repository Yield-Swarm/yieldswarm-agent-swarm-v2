# =============================================================================
# Provider & Terraform version pinning.
# Every credential consumed below is resolved from Vault at plan/apply time —
# there are no provider credentials in any .tf or .tfvars file.
# =============================================================================
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
      version = "~> 2.43"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.31"
    }
    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "~> 1.0"
    }
  }
}
