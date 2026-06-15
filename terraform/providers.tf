terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    runpod = {
      source  = "runpod/runpod"
      version = "~> 1.0"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
}

# ---------------------------------------------------------------------------
# Vault provider — authenticates using environment variables.
# Set VAULT_ADDR and either:
#   a) VAULT_TOKEN directly, or
#   b) VAULT_ROLE_ID + VAULT_SECRET_ID (AppRole) and let the wrapper script
#      exchange them for a token before running `terraform`.
# ---------------------------------------------------------------------------
provider "vault" {
  # Address and token are read from VAULT_ADDR / VAULT_TOKEN env vars.
  # No credentials are hardcoded here.
}

# ---------------------------------------------------------------------------
# Azure provider — credentials pulled from Vault at plan time.
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {}

  subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
  tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
  client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
  client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
}

# ---------------------------------------------------------------------------
# RunPod provider — API key pulled from Vault.
# ---------------------------------------------------------------------------
provider "runpod" {
  api_key = data.vault_kv_secret_v2.runpod.data["api_key"]
}

# ---------------------------------------------------------------------------
# Vultr provider — API key pulled from Vault.
# ---------------------------------------------------------------------------
provider "vultr" {
  api_key     = data.vault_kv_secret_v2.vultr.data["api_key"]
  rate_limit  = 700
  retry_limit = 3
}

# ---------------------------------------------------------------------------
# DigitalOcean provider — token pulled from Vault.
# ---------------------------------------------------------------------------
provider "digitalocean" {
  token             = data.vault_kv_secret_v2.digitalocean.data["token"]
  spaces_access_id  = data.vault_kv_secret_v2.digitalocean.data["spaces_access_id"]
  spaces_secret_key = data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"]
}
