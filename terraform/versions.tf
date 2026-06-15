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
      version = "~> 2.40"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    # RunPod has no official provider; we drive it with the http provider
    # against their REST API. The actual API key still comes from Vault.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket  = "yieldswarm-tfstate"
    key     = "infra/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table set via backend.hcl
  }
}
