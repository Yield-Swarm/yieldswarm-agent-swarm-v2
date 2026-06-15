provider "vault" {
  address          = var.vault_address
  skip_tls_verify  = var.vault_skip_tls_verify
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_approle_role_id
      secret_id = var.vault_approle_secret_id
    }
  }
}

# Azure credentials sourced from Vault — never hardcoded.
provider "azurerm" {
  features {}

  subscription_id = local.azure_secrets.subscription_id
  tenant_id       = local.azure_secrets.tenant_id
  client_id       = local.azure_secrets.client_id
  client_secret   = local.azure_secrets.client_secret
}

provider "digitalocean" {
  token = local.do_secrets.api_token
}

provider "vultr" {
  api_key = local.vultr_secrets.api_key
}

provider "runpod" {
  api_key = local.runpod_secrets.api_key
}
