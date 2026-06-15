# Provider configuration. The Vault provider authenticates first (via AppRole
# or VAULT_TOKEN); every other provider is then configured exclusively from
# secrets read out of Vault in vault.tf.

provider "vault" {
  # When empty, the provider reads VAULT_ADDR from the environment.
  address          = var.vault_address != "" ? var.vault_address : null
  skip_child_token = var.vault_skip_child_token

  # AppRole login is used only when a RoleID is provided; otherwise the provider
  # falls back to VAULT_TOKEN from the environment.
  dynamic "auth_login" {
    for_each = var.vault_role_id != "" ? [1] : []
    content {
      path = "auth/${var.vault_approle_path}/login"
      parameters = {
        role_id   = var.vault_role_id
        secret_id = var.vault_secret_id
      }
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = local.azure["arm_subscription_id"]
  client_id       = local.azure["arm_client_id"]
  client_secret   = local.azure["arm_client_secret"]
  tenant_id       = local.azure["arm_tenant_id"]
}

provider "runpod" {
  api_key = local.runpod["api_key"]
}

provider "vultr" {
  api_key = local.vultr["api_key"]
}

provider "digitalocean" {
  token = local.digitalocean["token"]
}
