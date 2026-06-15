provider "vault" {
  address   = var.vault_addr
  namespace = var.vault_namespace
}

provider "azurerm" {
  features {}

  subscription_id = local.azure_subscription_id
  client_id       = local.azure_client_id
  client_secret   = local.azure_client_secret
  tenant_id       = local.azure_tenant_id
}

provider "runpod" {
  api_key = local.runpod_api_key
}

provider "vultr" {
  api_key = local.vultr_api_key
}

provider "digitalocean" {
  token = local.do_token
}
