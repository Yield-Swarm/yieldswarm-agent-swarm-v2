# =============================================================================
# Cloud providers — every credential is sourced from the Vault data sources in
# vault.tf. No secrets are inlined, defaulted, or read from tfvars.
# =============================================================================

provider "azurerm" {
  features {}

  subscription_id = local.azure_creds["subscription_id"]
  tenant_id       = local.azure_creds["tenant_id"]
  client_id       = local.azure_creds["client_id"]
  client_secret   = local.azure_creds["client_secret"]
}

provider "digitalocean" {
  token             = local.digitalocean_creds["token"]
  spaces_access_id  = lookup(local.digitalocean_creds, "spaces_access_id", null)
  spaces_secret_key = lookup(local.digitalocean_creds, "spaces_secret_key", null)
}

provider "vultr" {
  api_key     = local.vultr_creds["api_key"]
  rate_limit  = 700
  retry_limit = 3
}

provider "runpod" {
  api_key = local.runpod_creds["api_key"]
}
