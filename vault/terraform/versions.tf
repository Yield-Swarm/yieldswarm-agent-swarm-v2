terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

# Vault provider authenticates via environment variables:
#   VAULT_ADDR  — e.g. https://vault.yieldswarm.io:8200
#   VAULT_TOKEN — root or admin token for the initial setup pass
#
# For ongoing management, replace VAULT_TOKEN with an admin AppRole:
#   VAULT_ROLE_ID + VAULT_SECRET_ID
provider "vault" {
  address = var.vault_addr

  # If you prefer AppRole over token-based auth, uncomment:
  # auth_login {
  #   path = "auth/approle/login"
  #   parameters = {
  #     role_id   = var.vault_admin_role_id
  #     secret_id = var.vault_admin_secret_id
  #   }
  # }
}
