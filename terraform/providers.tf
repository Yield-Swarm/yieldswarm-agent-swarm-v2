# =============================================================================
# Provider Configuration
# YieldSwarm AgentSwarm OS v2.0
#
# ALL provider credentials are pulled from Vault at plan/apply time.
# No secrets are stored in this file, tfvars, or environment variables
# (except for the Vault auth token itself, provided via VAULT_TOKEN or
# AppRole via VAULT_ROLE_ID + VAULT_SECRET_ID).
#
# Vault provider auth (choose one):
#   Option A — Token:    export VAULT_TOKEN=<token>
#   Option B — AppRole:  export VAULT_ROLE_ID=<id> VAULT_SECRET_ID=<id>
#              then use the vault_auth_backend_role_secret_id data source
#              or the vault_approle_auth_backend_login resource.
# =============================================================================

# -----------------------------------------------------------------------------
# Vault — the root of all secret retrieval
# -----------------------------------------------------------------------------
provider "vault" {
  address = var.vault_addr
  # Auth token is provided via VAULT_TOKEN environment variable.
  # For AppRole auth in CI, use a wrapper script that fetches the token:
  #   TOKEN=$(vault write -field=token auth/approle/login \
  #             role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID)
  #   export VAULT_TOKEN=$TOKEN
}

# -----------------------------------------------------------------------------
# Azure Resource Manager — credentials from Vault
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {}

  client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
  client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
  tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
  subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
}

# -----------------------------------------------------------------------------
# DigitalOcean — API token from Vault
# -----------------------------------------------------------------------------
provider "digitalocean" {
  token = data.vault_kv_secret_v2.digitalocean.data["api_token"]
}

# -----------------------------------------------------------------------------
# Vultr — API key from Vault
# -----------------------------------------------------------------------------
provider "vultr" {
  api_key     = data.vault_kv_secret_v2.vultr.data["api_key"]
  rate_limit  = 700
  retry_limit = 3
}

# -----------------------------------------------------------------------------
# RunPod — API key from Vault
# -----------------------------------------------------------------------------
provider "runpod" {
  api_key = data.vault_kv_secret_v2.runpod.data["api_key"]
}
