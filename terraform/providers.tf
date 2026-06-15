# ============================================================
# Terraform Provider Configuration — YieldSwarm AgentSwarm OS
#
# All provider credentials are pulled from Vault at plan/apply
# time via the vault_generic_secret data sources in secrets.tf.
# No credentials ever appear in .tfvars files or env vars.
#
# Authentication to Vault itself uses AppRole; pass credentials
# via the environment variables VAULT_ROLE_ID and
# VAULT_SECRET_ID (see terraform.tfvars.example for details).
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.39"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    runpod = {
      source  = "runpod/runpod"
      version = "~> 1.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ── Remote state backend ─────────────────────────────────
  # Uncomment and populate for production use.
  # backend "azurerm" {
  #   resource_group_name  = "yieldswarm-tfstate"
  #   storage_account_name = "yieldswarmtfstate"
  #   container_name       = "tfstate"
  #   key                  = "agentswarm.tfstate"
  # }
}

# ── Vault provider ────────────────────────────────────────────
# Auth: AppRole via environment variables.
#   VAULT_ADDR      — set to your Vault cluster URL
#   VAULT_ROLE_ID   — from: vault read auth/approle/role/yieldswarm-terraform/role-id
#   VAULT_SECRET_ID — from: vault write -f auth/approle/role/yieldswarm-terraform/secret-id
provider "vault" {
  address = var.vault_address
  # Vault provider automatically picks up VAULT_TOKEN if set,
  # or can use auth_login block for AppRole:
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
  skip_tls_verify = var.vault_skip_tls_verify
}

# ── Azure provider ────────────────────────────────────────────
# Credentials injected from Vault via data.vault_generic_secret
# (resolved after the vault provider authenticates).
provider "azurerm" {
  subscription_id = data.vault_generic_secret.azure.data["subscription_id"]
  tenant_id       = data.vault_generic_secret.azure.data["tenant_id"]
  client_id       = data.vault_generic_secret.azure.data["client_id"]
  client_secret   = data.vault_generic_secret.azure.data["client_secret"]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ── DigitalOcean provider ─────────────────────────────────────
provider "digitalocean" {
  token             = data.vault_generic_secret.do.data["token"]
  spaces_access_id  = data.vault_generic_secret.do.data["spaces_access_key"]
  spaces_secret_key = data.vault_generic_secret.do.data["spaces_secret_key"]
}

# ── Vultr provider ────────────────────────────────────────────
provider "vultr" {
  api_key     = data.vault_generic_secret.vultr.data["api_key"]
  rate_limit  = 100
  retry_limit = 3
}

# ── RunPod provider ───────────────────────────────────────────
provider "runpod" {
  api_key = data.vault_generic_secret.runpod.data["api_key"]
}
