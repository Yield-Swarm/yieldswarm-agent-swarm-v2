provider "vault" {
  address = var.vault_addr

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# Azure credentials sourced from Vault — never hardcoded.
provider "azurerm" {
  features {}

  subscription_id = local.azure.subscription_id
  client_id       = local.azure.client_id
  client_secret   = local.azure.client_secret
  tenant_id       = local.azure.tenant_id
}

provider "digitalocean" {
  token = local.digitalocean.token
}

provider "vultr" {
  api_key = local.vultr.api_key
}
