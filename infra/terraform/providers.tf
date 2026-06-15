provider "azurerm" {
  features {}

  subscription_id = local.azure_secrets["subscription_id"]
  tenant_id       = local.azure_secrets["tenant_id"]
  client_id       = local.azure_secrets["client_id"]
  client_secret   = local.azure_secrets["client_secret"]
  environment     = lookup(local.azure_secrets, "environment", "public")
}

provider "digitalocean" {
  token = local.digitalocean_secrets["token"]
}

provider "vultr" {
  api_key = local.vultr_secrets["api_key"]
}
