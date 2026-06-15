## providers.tf
## All cloud providers are configured exclusively from Vault-sourced data.
## Nothing in this file references *_API_KEY environment variables; that is
## a deliberate guardrail enforced by `tflint` and the CI `grep` check below
## (see scripts/tf-verify-no-env-creds.sh).

provider "azurerm" {
  features {}

  # Service principal authentication.  Subscription_id is the only non-secret.
  subscription_id = try(local.azure_creds["subscription_id"], null)
  tenant_id       = try(local.azure_creds["tenant_id"], null)
  client_id       = try(local.azure_creds["client_id"], null)
  client_secret   = try(local.azure_creds["client_secret"], null)
  use_oidc        = false
}

provider "digitalocean" {
  token             = try(local.digitalocean_creds["token"], null)
  spaces_access_id  = try(local.digitalocean_creds["spaces_access_key"], null)
  spaces_secret_key = try(local.digitalocean_creds["spaces_secret_key"], null)
}

provider "vultr" {
  api_key     = try(local.vultr_creds["api_key"], null)
  rate_limit  = 700
  retry_limit = 3
}

provider "runpod" {
  api_key = try(local.runpod_creds["api_key"], null)
}

provider "random" {}
provider "null" {}
