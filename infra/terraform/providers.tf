# =============================================================================
# Provider configuration.
#
# Vault is configured first; every other provider receives its credentials
# from `data.vault_kv_secret_v2.*` blocks in vault.tf. That means a clean
# `terraform init && terraform plan` requires nothing on disk except the
# Vault AppRole role_id + secret_id pair in TF_VAR_* env vars.
# =============================================================================

provider "vault" {
  address          = var.vault_address
  namespace        = var.vault_namespace != "" ? var.vault_namespace : null
  ca_cert_file     = var.vault_ca_cert_file
  skip_child_token = false

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_approle_role_id
      secret_id = var.vault_approle_secret_id
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = local.azure.subscription_id
  tenant_id       = local.azure.tenant_id
  client_id       = local.azure.client_id
  client_secret   = local.azure.client_secret
}

provider "digitalocean" {
  token             = local.digitalocean.api_token
  spaces_access_id  = local.digitalocean.spaces_access_key
  spaces_secret_key = local.digitalocean.spaces_secret_key
}

provider "vultr" {
  api_key     = local.vultr.api_key
  rate_limit  = 100
  retry_limit = 3
}
