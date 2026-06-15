# =========================================================================
# All cloud provider credentials are sourced from Vault data sources
# defined in vault.tf. The providers themselves never see env-var creds.
# =========================================================================

provider "azurerm" {
  features {}

  client_id       = local.azure_creds.client_id
  client_secret   = local.azure_creds.client_secret
  tenant_id       = local.azure_creds.tenant_id
  subscription_id = local.azure_creds.subscription_id

  # AzureRM 4.x requires this when using SP auth without OIDC/MSI.
  use_cli = false
}

provider "digitalocean" {
  token = data.vault_kv_secret_v2.digitalocean.data["token"]
}

provider "vultr" {
  api_key     = data.vault_kv_secret_v2.vultr.data["api_key"]
  rate_limit  = 700
  retry_limit = 3
}

# RunPod is driven through their REST API via the http provider.
# The API key is injected into per-request Authorization headers.
provider "http" {}

provider "random" {}
