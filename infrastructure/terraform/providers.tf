provider "azurerm" {
  features {}

  client_id       = local.azure_credentials.client_id
  client_secret   = local.azure_credentials.client_secret
  tenant_id       = local.azure_credentials.tenant_id
  subscription_id = local.azure_credentials.subscription_id
}

provider "runpod" {
  api_key = local.runpod_api_key
}

provider "vultr" {
  api_key = local.vultr_api_key
}

provider "digitalocean" {
  token = local.digitalocean_token
}
