# =============================================================================
# Terraform + provider version pinning.
# Update via the renovate bot - do not float minor versions in prod.
# =============================================================================
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.108"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
