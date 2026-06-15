provider "vault" {}

provider "azurerm" {
  features {}

  subscription_id = local.azure.subscription_id
  tenant_id       = local.azure.tenant_id
  client_id       = local.azure.client_id
  client_secret   = local.azure.client_secret
}

provider "runpod" {
  api_key = local.runpod.api_key
}

provider "vultr" {
  api_key = local.vultr.api_key
}

provider "digitalocean" {
  token = local.digitalocean.token
}
