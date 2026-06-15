terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.46"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.23"
    }
    # RunPod resources are managed via the HTTP provider (no dedicated TF provider).
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # Recommended: use a remote backend (S3/GCS/Azure Blob/Terraform Cloud)
  # so state is never stored locally alongside secrets.
  #
  # Example (uncomment and fill in):
  # backend "s3" {
  #   bucket         = "yieldswarm-tf-state"
  #   key            = "infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   kms_key_id     = "alias/terraform-state"
  #   dynamodb_table = "yieldswarm-tf-locks"
  # }
}

# ---------------------------------------------------------------------------
# Vault provider — authenticates via env vars set by vault-env.sh:
#   VAULT_ADDR, VAULT_TOKEN  (token from AppRole login is written there)
#
# The vault-env.sh wrapper script performs AppRole login and exports
# VAULT_TOKEN so that Terraform picks it up automatically here.
# ---------------------------------------------------------------------------
provider "vault" {}

# ---------------------------------------------------------------------------
# Azure provider — ARM_* env vars are set by vault-env.sh
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ---------------------------------------------------------------------------
# DigitalOcean provider — DIGITALOCEAN_TOKEN set by vault-env.sh
# ---------------------------------------------------------------------------
provider "digitalocean" {}

# ---------------------------------------------------------------------------
# Vultr provider — VULTR_API_KEY set by vault-env.sh
# ---------------------------------------------------------------------------
provider "vultr" {}
