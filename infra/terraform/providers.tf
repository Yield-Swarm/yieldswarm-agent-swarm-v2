provider "azurerm" {
  features {}

  environment     = var.azure_environment
  client_id       = lookup(local.azure, "ARM_CLIENT_ID", "")
  client_secret   = lookup(local.azure, "ARM_CLIENT_SECRET", "")
  tenant_id       = lookup(local.azure, "ARM_TENANT_ID", "")
  subscription_id = lookup(local.azure, "ARM_SUBSCRIPTION_ID", "")
}

provider "runpod" {
  api_key = lookup(local.runpod, "RUNPOD_API_KEY", "")
}

provider "vultr" {
  api_key = lookup(local.vultr, "VULTR_API_KEY", "")
}

provider "digitalocean" {
  token = lookup(local.digitalocean, "DIGITALOCEAN_TOKEN", "")
}

locals {
  # Modules can consume these locals for endpoints without copying secrets into
  # variables, tfvars, or committed files.
  rpc_endpoints = local.rpc
}
